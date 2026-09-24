// Morphology, InflectionRule and AttributeScopes.FoundationAttributes.morphology through the Foundation overlay,
// under Darling.
import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String) {
    print(condition ? "ok:" : "FAIL:", label)
    if !condition { failures += 1 }
}

var morphology = Morphology()
check(morphology.grammaticalGender == nil && morphology.partOfSpeech == nil && morphology.number == nil, "empty Morphology")
morphology.grammaticalGender = .feminine
morphology.partOfSpeech = .noun
morphology.number = .pluralFew
check(Morphology.GrammaticalGender.feminine.rawValue == 1 && Morphology.PartOfSpeech.abbreviation.rawValue == 14
      && Morphology.GrammaticalNumber.pluralMany.rawValue == 6, "raw values start at 1, as NSGrammaticalGender and friends")

let json = String(decoding: try JSONEncoder().encode(morphology), as: UTF8.self)
check(json.contains("\"grammaticalGender\":\"feminine\"") && json.contains("\"number\":\"few\"") && json.contains("\"partOfSpeech\":\"noun\""),
      "Codable uses the string forms (\(json))")
check(try JSONDecoder().decode(Morphology.self, from: Data(json.utf8)) == morphology, "Codable round trip")
check((try? JSONDecoder().decode(Morphology.self, from: Data(#"{"grammaticalGender":"other"}"#.utf8))) == nil, "an unknown value throws")

var pronoun = Morphology.CustomPronoun()
pronoun.subjectForm = "they"
check((try? morphology.setCustomPronoun(pronoun, forLanguage: "en")) == nil, "an incomplete custom pronoun is rejected")
pronoun.objectForm = "them"; pronoun.possessiveForm = "theirs"; pronoun.possessiveAdjectiveForm = "their"; pronoun.reflexiveForm = "themselves"
check((try? morphology.setCustomPronoun(pronoun, forLanguage: "en-US")) != nil && morphology.customPronoun(forLanguage: "EN-us") == pronoun,
      "a complete English custom pronoun is stored per language")
check(!Morphology.CustomPronoun.isSupported(forLanguage: "fr") && Morphology.CustomPronoun.requiredKeys(forLanguage: "en").count == 5,
      "custom pronouns are English-only")

check(InflectionRule(morphology: morphology) == .explicit(morphology), "InflectionRule(morphology:)")
check(String(decoding: try JSONEncoder().encode(InflectionRule.automatic), as: UTF8.self) == "true", "InflectionRule.automatic encodes as true")
check(!InflectionRule.canInflect(language: "en"), "no inflection engine")

var text = AttributedString("Ada")
text.morphology = morphology
check(text.morphology == morphology && text.runs[\.morphology].count == 1, "the morphology attribute")
check(AttributeScopes.FoundationAttributes.MorphologyAttribute.name == "NSMorphology"
      && AttributeScopes.FoundationAttributes.MorphologyAttribute.markdownName == "morphology", "attribute names")

let markdown = try AttributedString(markdown: "^[Ada](morphology: {grammaticalGender: 'feminine', partOfSpeech: 'noun'}) wrote",
                                    options: .init(allowsExtendedAttributes: true))
let parsed = markdown.runs[\.morphology].first { String(markdown[$0.1].characters) == "Ada" }?.0
check(parsed?.grammaticalGender == .feminine && parsed?.partOfSpeech == .noun, "morphology as a Markdown extended attribute")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
