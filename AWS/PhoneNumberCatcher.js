// AWS Lambda 
// Name: PhoneNumberCatcher
// Runtime: Node.js 6.10

const util = require('util');
console.log('Loading event');
var aws = require('aws-sdk');
var ddb = new aws.DynamoDB({params: {TableName: 'DevicePhoneNumbers'}});

exports.handler = function(event, context) {
  console.log('event:'+JSON.stringify(event));
  console.log('event.Records[0].Sns.Message:'+JSON.stringify(event.Records[0].Sns.Message));
  
  var snsMessageId = event.Records[0].Sns.MessageId;
  var snsPublishTime = event.Records[0].Sns.Timestamp;
  var snsTopicArn = event.Records[0].Sns.TopicArn;
  var lambdaReceiveTime = new Date().toString();
  var snsMessage = event.Records[0].Sns.Message;

  var snsMessageBody = JSON.parse(snsMessage);
  console.log('sns message parsed as json:'+JSON.stringify(snsMessageBody));
  var smsMessageBody = snsMessageBody.messageBody;
  var smsOriginationNumber = snsMessageBody.originationNumber;

  var promises = [];
  
  if (smsMessageBody.startsWith("device_uuid:")) {
      var deviceUuid = smsMessageBody.substring(12, smsMessageBody.length);
      console.log("Saving record for DeviceUuid: "+deviceUuid);
      var itemParams = {Item: {
          SnsPublishTime: {S: snsPublishTime}, 
          LambdaReceiveTime: {S: lambdaReceiveTime},
          DeviceUuid: {S: deviceUuid},
          OriginationNumber: {S: smsOriginationNumber}
      }};
      var putPromise2 = ddb.putItem(itemParams).promise().then(function() {
        console.log("put device successfully");
      }).catch( (error) => {
        console.log("Error putting item: "+JSON.stringify(error));
      });

      promises.push(putPromise2);      
  }
  else {
      console.log("unexpected message body: "+smsMessageBody);
  }
  
  console.log("Waiting for results");
  Promise.all(promises).then(function(values) {
    var results = values[0];
    context.done(null,'');
    console.log("Done waiting");
  }); 
  console.log("Function end");


};
