const serverless = require('serverless-http');
const app = require('./index');

// export the app for lambda
module.exports.handler = serverless(app)