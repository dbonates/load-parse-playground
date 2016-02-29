/*:
## Carregando e fazendo parse de JSON - básico
_por Daniel Bonates_
artigo relacionado: http://cocoaheadsbrasil.github.io/equinociOS/categoria/2016/03/02/2016-03-02-ios-web-e-json-sem-dependencias/
*/

import UIKit
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true


// um tipo de erro customizado para facilitar nossa leitura do retorno
enum NetError : ErrorType, CustomStringConvertible {
    case NotFound(Int)
    case Forbidden(Int)
    case ServerResponseError(Int)
    case FatalError(String)
    case Unknown
    
    var description:String {
        
        switch self {
            
        case let .NotFound(statusCode):
            return "Página não encontrada (Erro \(statusCode))"
        case let .Forbidden(statusCode):
            return "Acesso não permitido (Erro \(statusCode))"
        case let .ServerResponseError(statusCode):
            return "Servidor não está respondendo no momento (Erro \(statusCode))"
        case let .FatalError(errorDescription):
            return "Fatal error: \(errorDescription)"
        default:
            return "Erro desconhecido"
        }
    }
}

// uma func para buscar os dados da web, e fornecer retorno usando um callback tanto para erros quanto para os dados recuperados
func requestData(request:NSMutableURLRequest, callback:(AnyObject?, ErrorType?)-> ()) {
    
    let session = NSURLSession.sharedSession()
    
    let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
        
        if error != nil {
            callback(nil, NetError.FatalError((error?.localizedDescription)!))
            return
        }
        
        if let response = response as? NSHTTPURLResponse {
            
            switch response.statusCode {
                
            case 200..<300:
                callback(data ?? nil, nil)
            case 401:
                callback(nil, NetError.Forbidden(response.statusCode))
            case 404:
                callback(nil, NetError.NotFound(response.statusCode))
            case let x where x >= 500:
                callback(nil, NetError.ServerResponseError(response.statusCode))
            default:
                callback("anything happened and I don know what!", NetError.Unknown)
            }
        } else {
            callback("no response from server.", NetError.Unknown)
        }
    }
    
    task.resume()
    
}

// Um parser para extrair o json dos dados conseguidos na web
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

// exemplo com um caso de uso
if let url = NSURL(string: "https://gist.githubusercontent.com/dbonates/4bf4017dd770ccb1e680/raw/2590c37fc16294dbbc7c052d123295b76a707670/user_data_demo.json") {
    
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

