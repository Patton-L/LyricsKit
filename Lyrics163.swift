//
//  Lyrics163.swift
//
//  This file is part of LyricsX
//  Copyright (C) 2017  Xander Deng
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import SwiftyJSON

extension Lyrics.MetaData.Source {
    public static let Music163 = Lyrics.MetaData.Source("163")
}

public final class Lyrics163: CommonLyricsSource {
    
    let session = { () -> URLSession in
        let config = URLSessionConfiguration.default.with {
            $0.timeoutIntervalForRequest = 10
        }
        return URLSession(configuration: config)
    }()
    let dispatchGroup = DispatchGroup()
    
    func searchLyricsToken(criteria: Lyrics.MetaData.SearchCriteria, duration: TimeInterval, completionHandler: @escaping ([JSON]) -> Void) {
        let keyword = criteria.description
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .uriComponentAllowed)!
        let url = URL(string: "http://music.163.com/api/search/pc")!
        let body = "s=\(encodedKeyword)&offset=0&limit=10&type=1".data(using: .utf8)!
        
        let req = URLRequest(url: url).with {
            $0.httpMethod = "POST"
            $0.setValue("appver=1.5.0.75771", forHTTPHeaderField: "Cookie")
            $0.setValue("http://music.163.com/", forHTTPHeaderField: "Referer")
            $0.httpBody = body
        }
        let task = session.dataTask(with: req) { data, resp, error in
            let array = data.map(JSON.init)?["result"]["songs"].array ?? []
            completionHandler(array)
        }
        task.resume()
    }
    
    func getLyricsWithToken(token: JSON, completionHandler: @escaping (Lyrics?) -> Void) {
        guard let id = token["id"].number?.intValue else {
            completionHandler(nil)
            return
        }
        let url = URL(string: "http://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1")!
        let req = URLRequest(url: url)
        let task = session.dataTask(with: req) { data, resp, error in
            guard let json = data.map(JSON.init),
                let lrcContent = json["lrc"]["lyric"].string,
                let lrc = Lyrics(lrcContent) else {
                completionHandler(nil)
                return
            }
            if let transLrcContent = json["tlyric"]["lyric"].string,
                let transLrc = Lyrics(transLrcContent) {
                lrc.merge(translation: transLrc)
                lrc.metadata.includeTranslation = true
            }
            
            lrc.idTags[.title]   = token["name"].string
            lrc.idTags[.artist]  = token["artists"][0]["name"].string
            lrc.idTags[.album]   = token["album"]["name"].string
            lrc.idTags[.lrcBy]   = "163"
            
            lrc.metadata.source      = .Music163
            lrc.metadata.artworkURL  = token["album"]["picUrl"].url
            
            completionHandler(lrc)
        }
        task.resume()
    }
}

extension Lyrics {
    
    fileprivate func merge(translation: Lyrics) {
        var index = lyrics.startIndex
        var transIndex = translation.lyrics.startIndex
        while index < lyrics.endIndex, transIndex < translation.lyrics.endIndex {
            if lyrics[index].position == translation.lyrics[transIndex].position {
                let transStr = translation.lyrics[transIndex].sentence
                if transStr.characters.count > 0 {
                    lyrics[index].translation = transStr
                }
                lyrics.formIndex(after: &index)
                translation.lyrics.formIndex(after: &transIndex)
            } else if lyrics[index].position > translation.lyrics[transIndex].position {
                translation.lyrics.formIndex(after: &transIndex)
            } else {
                lyrics.formIndex(after: &index)
            }
        }
    }
}
