/*:
## Carregando e fazendo parse de JSON - intermediário
_por Daniel Bonates_
artigo relacionado: [http://equinocios.com/ios/2016/03/02/ios-web-e-json-sem-dependencias/](http://equinocios.com/ios/2016/03/02/ios-web-e-json-sem-dependencias/)
*/

import UIKit
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

/*
métodos utilitarios utilizados no parse
*/
func flatten<A>(x: A??) -> A? {
    if let y = x { return y }
    return nil
}

infix operator >>>= {}

func >>>= <A, B> (optional: A?, f: A -> B?) -> B? {
    return flatten(optional.map(f))
}

func number(input: [NSObject:AnyObject], key: String) -> NSNumber? {
    return input[key] >>>= { $0 as? NSNumber }
}

func int(input: [NSObject:AnyObject], key: String) -> Int? {
    return number(input, key: key).map { $0.integerValue }
}

func string(input: [String:AnyObject], key: String) -> String? {
    return input[key] >>>= { $0 as? String }
}

/*
definindo um protocol a ser adotado pelos models
*/
protocol JSONParselable {
    static func withJSON(json: [String:AnyObject]) -> Self?
}

/*
o model User e o protocolo implementado em uma extensão para diferenciar as tarefas
*/
struct User {
    var id:Int = 0
    var userFullname:String = ""
    var userAvatar:String = ""
}

/*
- essa implementação só retorna um User válido se os dados não opcionais forem recuperados do json.
- para retornar um User válido, basta passar um dicinário com os dados obrigatórios listados em guard
*/
extension User: JSONParselable {
    static func withJSON(json: [String:AnyObject]) -> User? {
        
        guard
        let id = int(json, key: "id"),
        userFullname = string(json, key: "user_fullname"),
        userAvatar = string(json, key: "user_avatar")
        else {
            return nil
        }
        
        let user = User(
            id: id,
            userFullname: userFullname,
            userAvatar: userAvatar
        )
        
        return user
    }
}

// a partir daqui é a solução proposta no artigo

// um tipo de erro customizado...
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
    
    requestData(request, callback: { (data, error) -> () in
        
        if let error = error {
            print(error)
            return
        }
        
        if let data = data as? NSData {
            
            if let usersJson = Parser.parseData(data) {
                
                print("aqui está seu json:\n\(usersJson)")
                
                let allUsersList = usersJson.flatMap(User.withJSON)
                
                // verificando...
                
                print("numero de usuarios no json: \(allUsersList.count)")
                
                print("usuario ZERO: \(allUsersList[0].userFullname)")
                print("usuario ÚLTIMO: \(allUsersList[allUsersList.count-1].userFullname)")
                
                print("avatar usuario ZERO: \(allUsersList[0].userFullname)")
                print("avatar usuario ÚLTIMO: \(allUsersList[allUsersList.count-1].userFullname)")
                
                guard
                    let imgUrl = NSURL(string: allUsersList[0].userAvatar),
                    let imgData = NSData(contentsOfURL:imgUrl)
                else {
                    return
                }
                
                let img = UIImage(data: imgData)
            }
            
        } else {
            print("nenhum json para intepretar.")
        }
        
    })
    
} else {
    print("url inválida")
}

