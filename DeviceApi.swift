//
//  DeviceApi.swift
//  PhoneNumberCapture
//
//  Created by David G. Young on 5/1/18.
//  Copyright © 2018 David G. Young. All rights reserved.
//

import Foundation

/*
curl -XPOST  https://asdfasfas.execute-api.us-east-1.amazonaws.com/test -d '{"device_uuid":"abcd123456"}'
{"device":{"lambda_receive_time":"Mon Apr 30 2018 18:12:16 GMT+0000 (UTC)","sns_publish_time":"2018-04-30T18:11:19.909Z","origination_number":"+1XXX5550100","device_uuid":"abcd123456"}}
*/

class DeviceApi {
  fileprivate static let ServicePath = "/test"
  fileprivate let server: String
  let session = URLSession(configuration: URLSessionConfiguration.default)
  var dataTask: URLSessionDataTask?
  
  init(server: String) {
    self.server = server
  }
    
  func query(deviceUuid: String, completionHandler: @escaping (_ jsonDict: [String:Any]?, _ error: String?) -> Void) {
    var request = URLRequest(url: URL(string: "\(server)\(DeviceApi.ServicePath)")!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringCacheData, timeoutInterval: TimeInterval(10))
    request.httpMethod = "POST"
    var responseError: String? = nil
    var bodyData: Data! = nil
    do {
       bodyData = try JSONSerialization.data(withJSONObject: ["device_uuid": deviceUuid],
                                             options: JSONSerialization.WritingOptions.prettyPrinted)
    }
    catch {
      NSLog("Can't serialize post data")
    }
    request.httpBody = bodyData

    dataTask = session.dataTask(with: request) {
      data, response, error in
      NSLog("Back from request")

      let response = response as? HTTPURLResponse
        
      var jsonDict: [String:Any]? = nil
      if let data = data {
        do {
          if let str = String(data: data, encoding: String.Encoding.utf8) {
            NSLog("JSON from server: \(str)")
          }
          if let result = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String:Any] {
            jsonDict = result
          }
          else {
            let message = "Cannot decode json due to nil deserilization result"
            NSLog(message)
            jsonDict = ["error": message]
          }
        }
        catch {
          responseError = "Cannot decode json due to exception"
        }
      }
      else {
        responseError = "Response body is unexpectedly nil"
      }
      
      if response == nil {
        responseError = "Response is unexpectedly nil"
      }
      else if response!.statusCode < 200 || response!.statusCode > 299 {
        if (responseError == nil) {
          responseError = "\(response!.statusCode)"
        }
      }
      completionHandler(jsonDict, responseError)
    }
    dataTask!.resume()
  }
  
}
