//
//  main.swift
//  TextParser
//
//  Created by Ilija Eftimov on 14/08/2022.
//

import Foundation
import NaturalLanguage
import ArgumentParser

@main
struct App: ParsableCommand {
    @Argument(help: "The text you want to analyze")
    var input: [String]
    
    @Flag(name: .shortAndLong, help: "Show detected language")
    var detectLanguage = false
    
    @Flag(name: .shortAndLong, help: "Prints how positive or negative the input is.")
    var sentimentAnalysis = false
    
    @Flag(name: .shortAndLong, help: "Shows the stem form of each word in the input.")
    var lemmatize = false
    
    @Flag(name: [.long, .customShort("v")], help: "Prints alternative words for each word in the input.")
    var alternatives = false
    
    @Flag(name: [.long, .customShort("p")], help: "Prints names of places in the input.")
    var places = false
    
    @Flag(name: [.long, .customShort("e")], help: "Prints names of people in the input.")
    var people = false
    
    @Flag(name: .shortAndLong, help: "Prints names of organizations in the input.")
    var organizations = false
    
    @Flag(name: .shortAndLong, help: "Enables all flags.")
    var all = false
    
    @Option(name: .shortAndLong, help: "The maximum number of alternatives to suggest.")
    var maximumAlternatives = 10
    
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "analyze",
            abstract: "Analyzes input text using a range of natural language approaches."
        )
    }
    
    mutating func run() {
        let text = input.joined(separator: " ")
        print()
        
        var language = NLLanguage.english
        
        if detectLanguage || all {
            language = NLLanguageRecognizer.dominantLanguage(for: text) ?? .undetermined
            print()
            print("Detected language: \(language.rawValue)")
        }
        
        if sentimentAnalysis || all  {
            let sentiment = sentiment(for: text)
            print("Sentiment: \(sentiment)")
        }
        
        lazy var lemma = lemmatize(for: text)
        
        if lemmatize || all {
            print()
            print("Found the following lemmas:")
            print("\t", lemma.formatted(.list(type: .and)))
        }
        
        if alternatives || all {
            print()
            print("Found the following alternatives:")
            for word in lemma {
                let embeddings = embeddings(for: word, language: language)
                print("\t\(word): ", embeddings.formatted(.list(type: .and)))
            }
        }
        
        if people || places || organizations || all {
            lazy var entities = entities(
                for: text,
                people: people || all,
                places: places || all,
                orgs: organizations || all
            )
            if !entities.isEmpty {
                print()
                print("Found the following entities:")
            
                for entity in entities {
                    print("\t", entity)
                }
            }
        }
    }
    
    func sentiment(for string: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = string
        
        let (sentiment, _) = tagger.tag(at: string.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }
    
    func embeddings(for word: String, language: NLLanguage) -> [String] {
        var results = [String]()
        
        if let embedding = NLEmbedding.wordEmbedding(for: language) {
            let similarWords = embedding.neighbors(for: word, maximumCount: maximumAlternatives)
            
            for word in similarWords {
                results.append("\(word.0) has a distance of \(word.1)")
            }
        }
        
        return results
    }
    
    func lemmatize(for string: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = string
        
        var results = [String]()
        
        tagger.enumerateTags(in: string.startIndex..<string.endIndex, unit: .word, scheme: .lemma) { tag, range in
            
            if (tag?.rawValue) != nil {
                let stemForm = String(string[range]).trimmingCharacters(in: .whitespaces)
                
                if !stemForm.isEmpty {
                    results.append(stemForm)
                }
            }
            
            return true
        }
        
        return results
    }
    
    func entities(for string: String, people: Bool, places: Bool, orgs: Bool) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = string
        var results = [String]()
        
        tagger.enumerateTags(in: string.startIndex..<string.endIndex, unit: .word, scheme: .nameType, options: .joinNames) { tag, range in
            
            guard let tag = tag else { return true }
            
            let match = String(string[range])
            switch tag {
            case .organizationName:
                if orgs {
                    results.append("Organization: \(match)")
                }
            case .personalName:
                if people {
                    results.append("Person: \(match)")
                }
            case .placeName:
                if places {
                    results.append("Place: \(match)")
                }
            default:
                break
            }
            
            return true
        }
        
        return results
    }
}
