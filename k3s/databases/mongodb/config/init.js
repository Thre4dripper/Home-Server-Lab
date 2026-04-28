// Idempotent RS initiation script — run manually with:
//   mongosh admin -u admin -p <pass> --file init.js
//
// Error code 23 = AlreadyInitialized, which is treated as success.

var result = rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-0.mongodb-headless.databases.svc.cluster.local:27017" },
    { _id: 1, host: "mongodb-1.mongodb-headless.databases.svc.cluster.local:27017" },
    { _id: 2, host: "mongodb-2.mongodb-headless.databases.svc.cluster.local:27017" }
  ]
});

if (result.ok !== 1 && result.code !== 23) {
  throw new Error("rs.initiate() failed: " + JSON.stringify(result));
}

print("Replica set: " + (result.code === 23 ? "already initialized" : "initialized OK"));
