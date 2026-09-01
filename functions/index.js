const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Cron job to run every day at midnight (WIB / Asia/Jakarta)
exports.checkExpiredTrials = functions.region('asia-southeast2')
  .pubsub.schedule('every day 00:00')
  .timeZone('Asia/Jakarta')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    
    try {
      // Find all villages with TRIAL status
      const villagesRef = db.collection('villages');
      const snapshot = await villagesRef.where('status', '==', 'TRIAL').get();
      
      if (snapshot.empty) {
        console.log('No trial villages found.');
        return null;
      }

      const batch = db.batch();
      let expiredCount = 0;

      snapshot.forEach(doc => {
        const data = doc.data();
        if (data.trialEndsAt) {
          const trialEndsAt = data.trialEndsAt.toDate();
          if (now > trialEndsAt) {
            batch.update(doc.ref, { status: 'EXPIRED' });
            expiredCount++;
          }
        }
      });

      if (expiredCount > 0) {
        await batch.commit();
        console.log(`Successfully expired ${expiredCount} villages.`);
      }
      
      return null;
    } catch (error) {
      console.error('Error running checkExpiredTrials:', error);
      return null;
    }
  });

exports.onChatMessageCreated = functions.region('asia-southeast2').firestore
  .document('chat_messages/{messageId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const senderName = data.senderName || 'Seseorang';
    const text = data.text || 'Mengirim pesan baru';
    const receiverId = data.receiverId;

    const db = admin.firestore();

    try {
      if (receiverId) {
        // Direct message
        const userDoc = await db.collection('users').doc(receiverId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData.fcmToken;
          if (fcmToken) {
            const message = {
              notification: {
                title: senderName,
                body: text,
              },
              android: {
                priority: 'high',
                notification: {
                  sound: 'default',
                  channelId: 'high_importance_channel',
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: 'default',
                  },
                },
              },
              token: fcmToken,
            };
            await admin.messaging().send(message);
            console.log('Successfully sent direct message notification to user:', receiverId);
          }
        }
      } else {
        // Group message (broadcast to 'all' topic)
        const message = {
          notification: {
            title: `${senderName} (Pesan Grup)`,
            body: text,
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'high_importance_channel',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
          topic: 'all',
        };
        await admin.messaging().send(message);
        console.log('Successfully sent group message notification to topic "all"');
      }
    } catch (error) {
      console.error('Error sending push notification:', error);
    }
    return null;
  });
