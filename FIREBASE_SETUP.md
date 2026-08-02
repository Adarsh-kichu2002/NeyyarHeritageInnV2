# Secure login setup

The app displays these usernames, but authenticates them using Firebase
Authentication email/password accounts:

| App username | Firebase Authentication email | Password |
| --- | --- | --- |
| `admin@neyyar` | `admin@neyyar.com` | `admin123` |
| `staff@neyyar` | `staff@neyyar.com` | `staff@321` |

## One-time Firebase Console setup

1. Open the project's Firebase Console and go to **Authentication** >
   **Sign-in method**. Enable **Email/Password**.
2. In **Authentication** > **Users**, create the two accounts shown above.
3. Copy the Firebase UID for each created account.
4. In **Firestore Database**, create these documents (replace the UID):

   - `users/ADMIN_UID`: `{ "role": "admin", "active": true }`
   - `users/STAFF_UID`: `{ "role": "staff", "active": true }`

5. In Firestore Database > **Rules**, replace the rules with the contents of
   `firestore.rules`, then publish them.
6. In Storage > **Rules**, replace the rules with the contents of
   `storage.rules`, then publish them.
7. Build and distribute this updated APK.

## Removing a resigned staff member

For every employee, create a separate Firebase Authentication account and a
matching `users/UID` document. To remove access, disable/delete their Firebase
Authentication user and change `active` to `false` in their profile document.
The Firestore/Storage rules deny access immediately, including from any old APK
that was never authenticated.

Do not save passwords in Firestore. Firebase Authentication stores passwords
securely and verifies them for the app.
