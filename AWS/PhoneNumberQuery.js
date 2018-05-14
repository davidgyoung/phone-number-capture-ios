// AWS Lambda 
// Name: PhoneNumberQuery
// Runtime: Node.js 6.10

const util = require('util');
console.log('querying devices');
var aws = require('aws-sdk');
var ddb = new aws.DynamoDB({params: {TableName: 'DevicePhoneNumbers'}});
const EventEmitter = require('events'); 

exports.handler = function(event, context, callback) {
  console.log("event: "+JSON.stringify(event));
  var deviceUuid = JSON.parse(event.body).device_uuid;
  console.log('querying by: '+deviceUuid);

  var eventEmitter = new EventEmitter();
  const params = {
    TableName: "DevicePhoneNumbers",
    Key: { DeviceUuid: {S: deviceUuid} }    
  };
  
  var responseStatusCode = 404;
  var responseBody = {};
  var promises = [];
  
  var queryPromise = ddb.getItem(params).promise().then(function(data, err) {
            console.log("got response from dynamodb");
            if (data && data.Item) {
                console.log("query data: "+JSON.stringify(data));
                const device = {
                    "lambda_receive_time": data.Item.LambdaReceiveTime.S,
                    "sns_publish_time": data.Item.SnsPublishTime.S,
                    "origination_number": data.Item.OriginationNumber.S,
                    "device_uuid": data.Item.DeviceUuid.S
                };
                responseStatusCode = 200;
                responseBody["device"] = device;
            }
            else {
              responseStatusCode = 404;
            }
  }).catch((err) => {
      console.log("no data.  err: "+JSON.stringify(err));
      responseStatusCode = 404;
      responseBody["error"] = err;
  });
  promises.push(queryPromise);
  
  console.log("Waiting for results");
  Promise.all(promises).then(function(values) {
    var results = values[0];
    const response = { statusCode: responseStatusCode, body: JSON.stringify(responseBody)};
    callback(null, response);    
    console.log("Done waiting");
  }); 
  console.log("Function end");
};