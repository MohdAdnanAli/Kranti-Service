// Deletes the demo database so the next "npm start" creates fresh demo data.
const fs = require('fs');
for (const f of ['kranti-transport.db', 'kranti-transport.db-wal', 'kranti-transport.db-shm']) fs.rmSync(f, { force: true });
console.log('Demo data deleted. Run "npm start" to create fresh demo data.');
