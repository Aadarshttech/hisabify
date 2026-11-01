# Firestore security-rule design notes (local review)

## Collections and observed access patterns

- `users/{uid}`: private account profile and selected-room cache. The app reads
  and updates its own document; room administrators also update a member's room
  cache when removing or transferring membership.
- `flats/{flatId}`: room metadata. A signed-in user can read the room only once
  they are a member, except during code-based joining and initial room creation.
- `flats/{flatId}/members/{memberId}`: room membership and role. Members read
  this list. Admins manage it. A new user may create exactly their own
  `Flatmate` membership while joining a room; this is deliberately restricted
  to their authenticated UID and email.
- `flats/{flatId}/expenses/{expenseId}` and `settlements/{settlementId}`:
  members read and write financial records. Admins may delete records or
  modify membership-related data.

## Important compatibility assumptions

1. Existing documents contain legacy optional fields, including display names,
   `rooms`, and server timestamps. Rules therefore validate known sensitive
   fields and bounds without requiring every optional legacy field.
2. A room code is an invitation secret in the current client architecture.
   Rules permit authenticated users to read a room for the join flow. For a
   stronger private-invite model, joining should move to a server-side callable
   function or one-time invitation document.
3. Firebase Auth email/password enforces unique account emails. Memberships are
   bound to authenticated UID; email is only descriptive data.
4. The client currently maintains other users' room caches after an admin
   change. The rules allow that narrow operation only to existing room admins.
