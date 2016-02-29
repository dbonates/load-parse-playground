import UIKit

import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

enum NetError : ErrorType, CustomStringConvertible {
    case NotFound
    case Forbidden
    case ServerError
    case Unknown
    
    var description:String {
        
        switch self {
            
        case .NotFound:
            return "Página não encontrada."
        case .Forbidden:
            return "Acesso não permitido."
        case .ServerError:
            return "Erro ao recuperar dados do servidor."
        default:
            return "Erro desconhecido."
        }
    }
}


func requestData(request:NSMutableURLRequest, callback:(AnyObject?, ErrorType?)-> ()) {
    
    let session = NSURLSession.sharedSession()
    
    let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
        
        if let response = response as? NSHTTPURLResponse {
            
            switch response.statusCode {
                
            case 200..<300:
                callback(data ?? nil, nil)
            case 401:
                callback("access denied!", NetError.Forbidden)
            case 404:
                callback("not found!", NetError.NotFound)
            case let x where x >= 500:
                print("server error!")
                callback("server error!", NetError.ServerError)
            default:
                callback("anything happened and I don know what!", NetError.Unknown)
            }
        } else {
            print ("no response")
        }
    }
    
    task.resume()
    
}

struct Parser {
    
    typealias StringObjectArrayDataFormat = [[String:AnyObject]]
    
    static func parseData(rawData: NSData) -> StringObjectArrayDataFormat? {
        
        do {
            if let json = try NSJSONSerialization.JSONObjectWithData(rawData, options: NSJSONReadingOptions.AllowFragments) as? StringObjectArrayDataFormat {
                return json
            } else {
                print("cannot serialize data returned in especified format")
            }
        } catch let error as NSError {
            print(error.description)
        }
        
        return nil
    }
}

if let url = NSURL(string: "https://gist.githubusercontent.com/dbonates/f3d0c4896941c9d0be31/raw/bc8a3f6fcc022fbc8fd38e9aa01d506e838f5451/demodata.json") {
    
    let request:NSMutableURLRequest = NSMutableURLRequest(URL:url)
    
    var namesArray:[String] = []
    
    requestData(request, callback: { (data, error) -> () in
        
        if let error = error {
            print(error)
            return
        }
        
        if let data = data as? NSData {
            if let json = Parser.parseData(data) {
                
                print("aqui está seu json:\n\(json)")
                
                for user in json {
                    if let userFullName = user["user_fullname"] as? String {
                        namesArray.append(userFullName)
                    }
                }
                print(namesArray)
            }
        } else {
            print("nenhum json para intepretar.")
        }
        
    })
    
} else {
    print("url inválida")
}

