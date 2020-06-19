//
//  APIClient.swift
//  TwilioVideoSample
//
//  Created by Lyndsey Scott on 6/17/20.
//  Copyright © 2020 Lyndsey Scott LLC. All rights reserved.
//

import Foundation


import UIKit
import CoreData

typealias APICompletionCallback = (_ responseObject: Any?, _ error: Error?) -> Void

enum AFHTTPClientParameterEncoding {
    case AFFormURLParameterEncoding
    case AFJSONParameterEncoding
    case AFPropertyListParameterEncoding
}

enum APIClientEncoding {
    case APIClientEncodingHTML
    case APIClientEncodingPropertyList
    case APIClientEncodingJSON
    case APIClientEncodingXML
    case APIClientEncodingFormURL
    case APIClientEncodingData
}

class APIClient: NSObject, NSFetchedResultsControllerDelegate {
    
    var session: URLSession?
    var teamLoadingSession: URLSession? // With extra long timeout for team loading bug
    var stringEncoding = String.Encoding.utf8
    var defaultHeaders: [String:String]!
    var parameterEncoding: AFHTTPClientParameterEncoding!
    var expectedResponseEncoding: APIClientEncoding!
    var errorDomain: String!
    var errorKey: String!
    var requireErrorKey: Bool!
    
    override init() {
        self.stringEncoding = String.Encoding.utf8
        self.parameterEncoding = .AFJSONParameterEncoding
        self.defaultHeaders = ["x-li-format":"json"]
        self.errorDomain = "APIClient"
        self.errorKey = "DefineThisKeyInTheSubClass"
        self.requireErrorKey = true
        self.expectedResponseEncoding = .APIClientEncodingHTML
        
        super.init()
        
        let config = URLSessionConfiguration.default
        let cachePath = NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent("spp.cache").path
        let myCache = URLCache(memoryCapacity: 16384, diskCapacity: 268435456, diskPath: cachePath)
        config.urlCache = myCache
        config.requestCachePolicy  = .useProtocolCachePolicy
        config.timeoutIntervalForResource = 60
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }
    
    // General method call
    func perform(_ method: String,
                 url: URL,
                 query: [String:Any]?,
                 body: String?,
                 header: [String:Any]?,
                 completion: @escaping APICompletionCallback) {
        let request = requestWithMethod(method, url: url, query: query ?? nil, body: body)
        
        if let header = header {
            for key in header.keys {
                let value = header[key]
                request.setValue(value as? String, forHTTPHeaderField: key)
            }
        }
        
        print("\n\(method): \(request.url ?? url)")
        print("query: \(query ?? [:])")
        print("body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")
        print("header: \(request.allHTTPHeaderFields ?? [:])")

        connect(request as URLRequest, completion)
    }
    
    func requestWithMethod(_ method: String,
                           url: URL,
                           query: [String:Any]?,
                           body: String?) -> NSMutableURLRequest {
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = self.defaultHeaders
        
        var requestURL = url
        if let query = query {
            let queryString = queryStringFromParameters(query, withEncoding: stringEncoding)
            requestURL = URL(string: url.absoluteString.appendingFormat(url.absoluteString.contains("?") ? "&\(queryString)" : "?\(queryString)")) ?? url
            request.url = requestURL
        }
        
        if let body = body, let encodedBody = body.data(using: self.stringEncoding) {
            request.httpBody = encodedBody
        }
        return request
    }
    
    func queryStringFromParameters(_ parameters: [String:Any]?, withEncoding stringEncoding: String.Encoding) -> String {
        
        var queryString = ""
        
        guard let parameters = parameters else {
            return queryString
        }
        
        for key in parameters.keys {
            var k:String? = key
            var p = parameters[key] as? String
            
            k = k?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            p = p?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            
            if let k = k, let p = p {
                queryString = queryString.appending("\(k)=\(p)&")
            }
        }
        
        return queryString
    }
    
    func connect(_ request: URLRequest, _ completion: APICompletionCallback?) {
        self.session?.dataTask(with: request) { (data, response, error) in
            // This comes back on an arbitrary thread, but must be moved to main
            //  thread for subsequent UI activity to work properly
            if error != nil {
                print("Connect Error: \(error?.localizedDescription ?? "nil")")
                completion?(nil, error as NSError?)
            } else if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 300 {
                print("Error status code: \(statusCode)")
                
                var errorMessage: String?
                
                if let data = data {
                    if self.expectedResponseEncoding == .APIClientEncodingJSON || self.expectedResponseEncoding == .APIClientEncodingData {
                        do {
                            let result = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                            if let jsonDict = result as? [String:Any] {
                                errorMessage = jsonDict["error"] as? String
                            }
                        } catch let e {
                            print(e)
                        }
                    } else if self.expectedResponseEncoding == .APIClientEncodingHTML {
                        let result = String(data: data, encoding: String.Encoding.ascii)
                        errorMessage = result
                        if let stringData = result?.data(using: .utf8) {
                            do {
                                if let jsonDict = try JSONSerialization.jsonObject(with: stringData, options : .allowFragments) as? [String: Any] {
                                    errorMessage = jsonDict["error"] as? String
                                }
                            } catch {}
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    completion?(nil, NSError(domain: "APIClientErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : errorMessage]))
                } else {
                    completion?(nil, NSError(domain: "APIClientErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : ""]))
                }
                
            } else if let data = data {
                
                var result:Any?
                
                if self.expectedResponseEncoding == .APIClientEncodingJSON {
                    do {
                        result = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    } catch let e {
                        print(e)
                    }
                } else if self.expectedResponseEncoding == .APIClientEncodingHTML {
                    result = String(data: data, encoding: String.Encoding.ascii)
                } else if self.expectedResponseEncoding == .APIClientEncodingData {
                    result = data
                }
                
                // Uncomment to print response for debugging
                if let dataResult = result as? Data {
                    do {
                        print(try JSONSerialization.jsonObject(with: dataResult, options: .allowFragments))
                    } catch let e {
                        print(e)
                    }
                } else {
                    print(result ?? "nil")
                }
                
                if result == nil {
                    print("Return data could not be parsed: \(String(describing: String(data: data, encoding: String.Encoding.utf16)))")
                    if let completion = completion {
                        completion(nil, NSError(domain: "APIClientErrorDomain", code: 0, userInfo: nil))
                    }
                } else if let result = result, let completion = completion, self.session != nil {
                    completion(result, nil)
                }
            }
        }.resume()
    }
}


extension APIClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let urlCredential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, urlCredential)
        }
    }
}
