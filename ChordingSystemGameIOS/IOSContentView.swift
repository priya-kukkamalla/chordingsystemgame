import SwiftUI
import Combine

// MARK: - Haptic

func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

// MARK: - Chord Maps

let layer1: [Int: String] = [
    1:       "E",  2:       "T",  4:       "A",  8:       "I",
    1+2:     "N",  1+4:     "S",  1+8:     "R",  2+4:     "H",
    2+8:     "L",  4+8:     "D",  1+2+4:   "C",  1+2+8:   "U",
    1+4+8:   "O",  2+4+8:   "M",  1+2+4+8: "F",
]

let layer2: [Int: String] = [
    1:       "P",  2:       "W",  4:       "B",  8:       "G",
    1+2:     "V",  1+4:     "K",  1+8:     "Y",  2+4:     "J",
    2+8:     "X",  4+8:     "Q",  1+2+4:   "Z",  1+2+8:   ".",
    1+4+8:   ",",  2+4+8:   "?",  1+2+4+8: "!",
]

let thumbChords: [Int: String] = [
    1: "space", 2: "backspace", 4: "newline", 8: "deleteword", 1+2: "space",
]

func chordFor(_ ch: String) -> (mask: Int, layer2: Bool)? {
    if let m = layer1.first(where: { $0.value == ch }) { return (m.key, false) }
    if let m = layer2.first(where: { $0.value == ch }) { return (m.key, true) }
    return nil
}

// MARK: - Level Definition

enum LevelMode {
    case letters([String])              // flash a letter, user hits it
    case words([String])                // type a whole word letter-by-letter + space
    case sentences([String])            // type a full sentence with spaces + punct
}

struct GameLevel {
    let number:      Int
    let section:     String             // e.g. "Layer 1", "Layer 2", "Words"
    let title:       String
    let description: String
    let mode:        LevelMode
    let targetCount: Int                // letters correct / words complete / sentences complete
    let timeLimit:   Double?
    let showHint:    Bool
    let requireLayer2: Bool             // auto-switch engine to L2 at start
}

// Convenience builders
private func L(_ letters: String...) -> LevelMode { .letters(letters) }
private func L(_ arr: [String])      -> LevelMode { .letters(arr) }
private func W(_ words: String...)   -> LevelMode { .words(words) }
private func W(_ arr: [String])      -> LevelMode { .words(arr) }
private func S(_ sentences: String...) -> LevelMode { .sentences(sentences) }
private func S(_ arr: [String])        -> LevelMode { .sentences(arr) }

// ── Layer 1 word pool ────────────────────────────────────────────────────────
// Letters available: E T A I N S R H L D C U O M F
// (no B G J K P Q V W X Y Z and no punctuation)
private let l1Words = [
    // 2–3 letters
    "HE","SHE","THE","AND","ARE","HIS","HER","NOT","OUT","ALL",
    "HAD","HAS","CAN","DID","ITS","LET","SET","MEN","END","OLD",
    "OUR","OWN","SAT","RAN","TEN","TON","NOR","SUN","ACE","ICE",
    // 4 letters
    "THAT","THIS","THEM","THEN","THAN","SAID","FIND","SUCH","EACH",
    "ALSO","LAST","SAME","NEED","TELL","HOLD","FACE","ROOM","DOOR",
    "LAND","HAND","MIND","LINE","LIFE","SIDE","REAL","DEAL","LEAD",
    "ROAD","MEAL","SORT","FORM","LORD","HORN","LORE","HIRE","MICE",
    // 5+ letters
    "THEIR","THERE","THESE","THOSE","OFTEN","SINCE","UNTIL","OTHER",
    "COULD","WOULD","STILL","SMALL","TIRED","TRIED","HEART","EARTH",
    "NORTH","STORM","TREND","TROTH","STOOL","SMILE","SNAIL","TRAIL",
    "SHIRT","SHELL","SHELF","SHADE","SHAME","SHARE","SHARD","CHORE",
    "CLEAN","CLONE","CLOSE","CLOTH","CLOUD","CLOUT","CRANE","STAFF",
    "STONE","STORE","STARE","STAND","STEEL","COAST","TOAST","ROAST",
    "MEANT","SCENT","DENTS","RENTS","LINED","MINED","MINER","LINEN",
    "THIRD","THRICE","DRIED","DRIEST","DETAIL","DENTAL","MENTAL","RENTAL",
]

// ── Layer 2 word pool ────────────────────────────────────────────────────────
// Letters available: P W B G V K Y J X Q Z (plus . , ? ! but skip punct in words)
// L2 has no vowels except via layer switch — so use words that ALSO need L1 vowels.
// Strategy: short common words that HAPPEN to use several L2 consonants.
private let l2Words = [
    // Heavy on L2 consonants — player must switch layers for vowels
    "WALK","WORK","WEEK","PARK","PORK","PICK","PACK","BACK","BOOK","BIKE",
    "GIVE","GAME","GATE","GOAL","GOOD","GRAB","GRAY","GROW","GRIP","GRIN",
    "KEEP","KING","KIND","KNEW","KNOW","KNOB","PAVE","WOKE","YELL","YOGA",
    "JUNK","JUMP","JACK","JADE","JOBS","JOIN","JOKE","JOLT","JUST","JAWS",
    "VIBE","VIEW","VINE","VOID","VOTE","VARY","VAST","VENT","VERB","VEST",
    "WAND","WARD","WARM","WARN","WARP","WART","WAVY","WINK","WISP","WISH",
    "YANK","YARD","YARN","YAWN","YEAR","YOKE","YOUR","YAWL",
    "BAKE","BALE","BALL","BAND","BANG","BANK","BARE","BARK","BARN","BASE",
    "BOWL","BOLD","BOLT","BOND","BONE","BORE","BORN","BROW","BREW","BRED",
    "PEAK","PEEL","PERK","PETAL","PIVOT","PIXEL","PLANK","PLAY","PLOW","PLUG",
    "GAWK","GAZE","GELD","GERM","GIFT","GILD","GLEE","GLEN","GLOB","GLOW",
    "KNAP","KNAVE","KNEEL","KNELT","KNIT","KNOP","KNOT","KNOWN","KNURL",
    "KVETCH","JAZZY","JIFFY","JIBED","JOKEY","JUMPY","JUKED","JUKED",
]

// ── Mixed layer word pool ─────────────────────────────────────────────────────
private let mixedWords = [
    // Everyday words that pull from both layers naturally
    "MAKE","TAKE","WAKE","BAKE","LAKE","FAKE","CAKE","RAKE","SAKE",
    "CAME","GAME","SAME","FAME","NAME","TAME","DAME","LAME","GAZE",
    "ABLE","CABLE","TABLE","FABLE","STABLE","LABEL",
    "WORLD","WORTH","WORST","WORKS","WORDS","WORMS","WORRY","WORSE",
    "PLACE","PLANE","PLANT","PLATE","PLANK","PLAIN","PLAID","PLAGUE",
    "BRING","BRAIN","BRAID","BRAND","BRAKE","BRAVE","BROAD","BROKE",
    "THINK","THING","THICK","THIRD","THINE","THORN","THOSE","THROW",
    "GREAT","GREET","GREEN","GREED","GROAN","GROIN","GROOM","GROVE",
    "PEOPLE","SIMPLE","SAMPLE","STAPLE","TEMPLE","PURPLE","TRIPLE",
    "BEFORE","BETTER","BELONG","BESIDE","BEYOND","BEWAIL","BEWARE",
    "STREET","STRONG","STRIDE","STRIKE","STRING","STRAP","STRAW",
    "FRIEND","FROZEN","FROWNS","FRAMES","FRANCE","FRIGHT","FRINGE",
    "TOWARD","TRAVEL","TRACK","TRADE","TRAIN","TRAIT","TRAMP","TRANCE",
    "SCHOOL","SCREEN","SCRUB","SCREW","SCROLL","SCRIMP","SCRIM",
    "PROBLEM","PRODUCE","PROGRAM","PROJECT","PROMISE","PROMOTE","PROTECT",
    "BETWEEN","CAPABLE","CAREFUL","CENTRAL","CERTAIN","CHAPTER","CLASSIC",
    "DEVELOP","DIGITAL","DISPLAY","DISTANT","DIVERSE","DRIVING","DYNAMIC",
    "EVENING","EXAMPLE","EXACTLY","EXPLAIN","EXPRESS","EXTREME","EYEBROW",
    "FORWARD","FREEDOM","FURTHER","GENERAL","GETTING","GETTING","GROWING",
]

// ── Layer-1-only sentences ────────────────────────────────────────────────────
// Uses only E T A I N S R H L D C U O M F — no layer switching needed
private let l1EasySentences = [
    "THE CAT SAT",
    "HE RAN THEN FELL",
    "SHE SAID HELLO",
    "FIND THE TRAIL",
    "STAND AND TURN",
    "HIS CAR IS HERE",
    "COME AND SEE ME",
    "THAT IS NOT IT",
    "THERE IS NO TIME",
    "HOLD THE LINE",
]
private let l1MedSentences = [
    "THE FISH SWAM IN THE SEA",
    "HIS CAR WAS THERE ALL MORNING",
    "THOSE ARE SOME NICE HILLS",
    "COULD YOU FIND THE ROAD",
    "THEIR MOTHER CAME HOME LATE",
    "SHE HELD HER CHILD CLOSE",
    "THE SUN SHONE ON THE HILLS",
    "HE DID NOT SHOUT OR SCREAM",
    "TURN THE DIAL UNTIL IT CLICKS",
    "THE TRAIL ENDS AT THE SHORE",
]
private let l1HardSentences = [
    "THE DETAILS OF THE MATTER ARE NOT CLEAR",
    "HE FINISHED HIS MEAL THEN LEFT THE ROOM",
    "SHE FOUND THE COIN UNDER THE OLD CHEST",
    "THEIR HOME STOOD NEAR THE FOOT OF THE HILL",
    "THE TIDE CAME IN AND SOAKED THE SAND",
    "HE SAID THE ROAD NORTH SHOULD SUIT THEM FINE",
    "THOSE WHO STOOD THEIR GROUND DID NOT RETREAT",
    "THE SMELL OF FRESH RAIN FILLED THE STREET",
    "SHE SMILED AND TOLD HIM THE HONEST TRUTH",
    "FIND THE THREAD AND FOLLOW IT TO THE END",
]

// ── Mixed layer sentences ─────────────────────────────────────────────────────
private let mixedEasySentences = [
    "PICK UP THE BLUE BAG",
    "WAKE UP AND GO FOR A WALK",
    "THE BOY KEPT A BIG PIG",
    "SHE FOUND THE KEY",
    "GIVE IT YOUR BEST",
    "THE PARK WAS BRIGHT AND GREEN",
    "HE PLAYED WELL TODAY",
    "KEEP GOING AND WORK HARD",
    "THE VIEW FROM THE BRIDGE WAS GREAT",
    "SAVE YOUR WORK BEFORE YOU LEAVE",
]
private let mixedMedSentences = [
    "SHE FOUND THE KEY AND OPENED THE BOX",
    "THE BOY KEPT HIS PIG IN A BIG PEN",
    "WAKE UP EARLY AND GO FOR A WALK",
    "PICK UP THE BLUE BAG BY THE GATE",
    "GIVE IT YOUR BEST AND KEEP GOING",
    "THE KING GAVE THE PEOPLE WORK AND BREAD",
    "HE GRABBED THE ROPE AND BEGAN TO CLIMB",
    "THEY DROVE PAST THE PARK ON THEIR WAY HOME",
    "THE BRAVE KNIGHT KEPT WATCH BY THE GATE",
    "SHE PACKED HER BAG AND WALKED TO THE VILLAGE",
]
private let mixedHardSentences = [
    "THE SIMPLE TRUTH IS THAT PEOPLE MAKE MISTAKES",
    "BRING YOUR BEST WORK AND SHOW WHAT YOU CAN DO",
    "EVERY GREAT STORY STARTS WITH A SINGLE STEP",
    "THINK ABOUT WHAT MIGHT HAPPEN IF YOU TRY",
    "SMALL CHANGES OFTEN BRING BIG RESULTS OVER TIME",
    "THE PROBLEM WITH BEING TOO CAREFUL IS THAT YOU STOP GROWING",
    "PICK YOURSELF UP AND TRY AGAIN WITH A CLEAR PLAN",
    "GREAT WORK TAKES TIME AND PATIENCE AND WILLPOWER",
    "KEEP YOUR GOALS IN VIEW AND MAKE PROGRESS EVERY DAY",
    "THE BEST WAY TO LEARN IS TO KEEP MAKING THINGS",
]

// ── Punctuation sentences ─────────────────────────────────────────────────────
// Uses L2 punctuation: . , ? !
private let punctSentences = [
    "WAIT, IS THAT RIGHT?",
    "YES. NO. MAYBE.",
    "WHAT TIME IS IT? I NEED TO KNOW.",
    "HE SAID, COME IN. SHE DID.",
    "REALLY? THAT IS AMAZING!",
    "WELL, THAT WAS UNEXPECTED.",
    "IS THIS THE CORRECT PATH? I THINK SO.",
    "STOP. LOOK. LISTEN.",
    "COULD YOU HELP ME? PLEASE.",
    "WOW! THAT IS REALLY SOMETHING.",
    "HOLD ON, I NEED A MOMENT.",
    "ARE YOU SURE? YES, I AM SURE.",
    "THE ANSWER IS NO. FINAL ANSWER.",
    "WAIT! COME BACK. I FORGOT SOMETHING.",
    "GREAT WORK! KEEP IT UP.",
]

let gameLevels: [GameLevel] = [

    // ── LAYER 1: LETTERS ─────────────────────────────────────────────────────

    GameLevel(number: 1,  section:"Layer 1", title:"One Finger",
              description:"Index→E  Middle→T  Ring→A  Pinky→I",
              mode: L("E","T","A","I"),
              targetCount:12, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number: 2,  section:"Layer 1", title:"Singles Practice",
              description:"Get comfortable with E T A I.",
              mode: L("E","T","A","I"),
              targetCount:20, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number: 3,  section:"Layer 1", title:"Singles Speed",
              description:"E T A I — 30 seconds.",
              mode: L("E","T","A","I"),
              targetCount:20, timeLimit:30, showHint:false, requireLayer2:false),

    GameLevel(number: 4,  section:"Layer 1", title:"Two Fingers",
              description:"Two-finger chords: N S R H L D",
              mode: L("N","S","R","H","L","D"),
              targetCount:18, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number: 5,  section:"Layer 1", title:"Singles + Doubles",
              description:"All 10 chords so far.",
              mode: L("E","T","A","I","N","S","R","H","L","D"),
              targetCount:24, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number: 6,  section:"Layer 1", title:"Three Fingers",
              description:"Three-finger chords: C U O M F",
              mode: L("C","U","O","M","F"),
              targetCount:20, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number: 7,  section:"Layer 1", title:"Full Layer 1",
              description:"All 15 Layer 1 chords.",
              mode: L("E","T","A","I","N","S","R","H","L","D","C","U","O","M","F"),
              targetCount:30, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number: 8,  section:"Layer 1", title:"Layer 1 Speed",
              description:"All 15 — 45 seconds.",
              mode: L("E","T","A","I","N","S","R","H","L","D","C","U","O","M","F"),
              targetCount:30, timeLimit:45, showHint:false, requireLayer2:false),

    // ── LAYER 1: WORDS ───────────────────────────────────────────────────────

    GameLevel(number: 9,  section:"Layer 1", title:"First Words",
              description:"Short words — only Layer 1 letters. Thumb+I = space.",
              mode: W("THE","AND","HIS","HER","ARE","THIS","THAT","THEN",
                      "THEM","THAN","SAID","FIND","SOME","HOLD","TOLD"),
              targetCount:10, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number:10,  section:"Layer 1", title:"L1 Words",
              description:"Longer words using only Layer 1.",
              mode: W(l1Words),
              targetCount:12, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:11,  section:"Layer 1", title:"L1 Words Speed",
              description:"Layer 1 words — 60 seconds.",
              mode: W(l1Words),
              targetCount:12, timeLimit:60, showHint:false, requireLayer2:false),

    // ── LAYER 1: SENTENCES ───────────────────────────────────────────────────

    GameLevel(number:12,  section:"Layer 1", title:"First Sentences",
              description:"Short sentences — Layer 1 only.",
              mode: S(l1EasySentences),
              targetCount:5, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:13,  section:"Layer 1", title:"L1 Sentences",
              description:"Longer Layer 1 sentences.",
              mode: S(l1MedSentences),
              targetCount:5, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:14,  section:"Layer 1", title:"L1 Hard Sentences",
              description:"Complex Layer 1 sentences — no hints.",
              mode: S(l1HardSentences),
              targetCount:4, timeLimit:nil, showHint:false, requireLayer2:false),

    // ── LAYER 2: LETTERS ─────────────────────────────────────────────────────

    GameLevel(number:15,  section:"Layer 2", title:"L2 Singles",
              description:"Tap thumb to switch to Layer 2. P W B G",
              mode: L("P","W","B","G"),
              targetCount:12, timeLimit:nil, showHint:true, requireLayer2:true),

    GameLevel(number:16,  section:"Layer 2", title:"L2 Singles Practice",
              description:"Get comfortable switching layers.",
              mode: L("P","W","B","G"),
              targetCount:20, timeLimit:nil, showHint:true, requireLayer2:true),

    GameLevel(number:17,  section:"Layer 2", title:"L2 Singles Speed",
              description:"P W B G — 30 seconds.",
              mode: L("P","W","B","G"),
              targetCount:20, timeLimit:30, showHint:false, requireLayer2:true),

    GameLevel(number:18,  section:"Layer 2", title:"L2 Two Fingers",
              description:"Two-finger L2 chords: V K Y J X Q",
              mode: L("V","K","Y","J","X","Q"),
              targetCount:18, timeLimit:nil, showHint:true, requireLayer2:true),

    GameLevel(number:19,  section:"Layer 2", title:"L2 Singles + Doubles",
              description:"All 10 Layer 2 chords so far.",
              mode: L("P","W","B","G","V","K","Y","J","X","Q"),
              targetCount:24, timeLimit:nil, showHint:true, requireLayer2:true),

    GameLevel(number:20,  section:"Layer 2", title:"L2 Three Fingers",
              description:"Three-finger L2 chords: Z . , ? !",
              mode: L("Z",".",",","?","!"),
              targetCount:20, timeLimit:nil, showHint:true, requireLayer2:true),

    GameLevel(number:21,  section:"Layer 2", title:"Full Layer 2",
              description:"All 15 Layer 2 chords.",
              mode: L("P","W","B","G","V","K","Y","J","X","Q","Z",".",",","?","!"),
              targetCount:30, timeLimit:nil, showHint:false, requireLayer2:true),

    GameLevel(number:22,  section:"Layer 2", title:"Layer 2 Speed",
              description:"All 15 L2 chords — 45 seconds.",
              mode: L("P","W","B","G","V","K","Y","J","X","Q","Z",".",",","?","!"),
              targetCount:30, timeLimit:45, showHint:false, requireLayer2:true),

    // ── LAYER 2: WORDS ───────────────────────────────────────────────────────

    GameLevel(number:23,  section:"Layer 2", title:"L2 First Words",
              description:"Short words heavy on L2 consonants.",
              mode: W("WALK","WORK","BACK","BOOK","BIKE","GOOD","KEEP","JUMP",
                      "PLAY","BOLD","GRAB","VIEW","VINE","YELL","WARM"),
              targetCount:10, timeLimit:nil, showHint:true, requireLayer2:false),

    GameLevel(number:24,  section:"Layer 2", title:"L2 Words",
              description:"Longer words using Layer 2 consonants.",
              mode: W(l2Words),
              targetCount:12, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:25,  section:"Layer 2", title:"L2 Words Speed",
              description:"Layer 2 words — 60 seconds.",
              mode: W(l2Words),
              targetCount:12, timeLimit:60, showHint:false, requireLayer2:false),

    // ── BOTH LAYERS: LETTERS ─────────────────────────────────────────────────

    GameLevel(number:26,  section:"Both Layers", title:"Layer Switch Drill",
              description:"Common letters from both layers — switch freely.",
              mode: L("E","T","A","I","N","S","P","W","B","G","R","H","Y","K"),
              targetCount:30, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:27,  section:"Both Layers", title:"All 30 Chords",
              description:"Every letter from both layers.",
              mode: L(Array(layer1.values) + Array(layer2.values)),
              targetCount:30, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:28,  section:"Both Layers", title:"Speed Run",
              description:"All 30 chords — 60 seconds.",
              mode: L(Array(layer1.values) + Array(layer2.values)),
              targetCount:40, timeLimit:60, showHint:false, requireLayer2:false),

    // ── BOTH LAYERS: WORDS ───────────────────────────────────────────────────

    GameLevel(number:29,  section:"Words", title:"Mixed Words",
              description:"Common words across both layers.",
              mode: W(mixedWords),
              targetCount:12, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:30,  section:"Words", title:"Mixed Words Speed",
              description:"Mixed words — 60 seconds.",
              mode: W(mixedWords),
              targetCount:12, timeLimit:60, showHint:false, requireLayer2:false),

    // ── SENTENCES ────────────────────────────────────────────────────────────

    GameLevel(number:31,  section:"Sentences", title:"Easy Sentences",
              description:"Short mixed sentences with spaces.",
              mode: S(mixedEasySentences),
              targetCount:5, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:32,  section:"Sentences", title:"Medium Sentences",
              description:"Longer mixed sentences.",
              mode: S(mixedMedSentences),
              targetCount:5, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:33,  section:"Sentences", title:"Hard Sentences",
              description:"Long sentences — both layers, full accuracy.",
              mode: S(mixedHardSentences),
              targetCount:4, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:34,  section:"Sentences", title:"Punctuation",
              description:"Sentences with . , ? ! — Layer 2 required.",
              mode: S(punctSentences),
              targetCount:5, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:35,  section:"Sentences", title:"Sentence Sprint",
              description:"Medium sentences — 90 seconds.",
              mode: S(mixedMedSentences),
              targetCount:5, timeLimit:90, showHint:false, requireLayer2:false),

    GameLevel(number:36,  section:"Sentences", title:"Punctuation Sprint",
              description:"Punctuation sentences — 90 seconds.",
              mode: S(punctSentences),
              targetCount:5, timeLimit:90, showHint:false, requireLayer2:false),

    GameLevel(number:37,  section:"Sentences", title:"Hard Sprint",
              description:"Hard sentences — 120 seconds.",
              mode: S(mixedHardSentences),
              targetCount:4, timeLimit:120, showHint:false, requireLayer2:false),

    GameLevel(number:38,  section:"Sentences", title:"Mixed Sprint",
              description:"All sentence types shuffled.",
              mode: S(mixedEasySentences + mixedMedSentences + punctSentences),
              targetCount:6, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:39,  section:"Sentences", title:"Full Marathon",
              description:"Long sentences, no time limit. Pure endurance.",
              mode: S(mixedHardSentences + l1HardSentences),
              targetCount:6, timeLimit:nil, showHint:false, requireLayer2:false),

    GameLevel(number:40,  section:"Sentences", title:"Grand Finale",
              description:"60 chords from all layers. No hints. No mercy.",
              mode: L(Array(layer1.values) + Array(layer2.values)),
              targetCount:60, timeLimit:nil, showHint:false, requireLayer2:false),
]


// MARK: - Calibration Model
//
// One finger layout, learned from where your fingers actually land and persisted.
// Positions are normalized 0...1 across the WHOLE screen, so fingers can rest anywhere.

struct Landing {
    let zone:  Int       // finger bit 1,2,4,8 (16 = thumb placement during calibration)
    let point: CGPoint   // 0...1 relative to the chord panel (the full screen)
}

struct FingerLayout {
    var cx: [CGFloat]
    var cy: [CGFloat]
    var devY: [CGFloat]
    var placed: [Bool] = Array(repeating: true, count: 4)

    static func defaults() -> FingerLayout {
        FingerLayout(cx: (0..<4).map { 0.28 + 0.70 * (CGFloat($0) + 0.5) / 4 },
                     cy: Array(repeating: 0.61, count: 4),
                     devY: Array(repeating: 0.058, count: 4))
    }
    func halfH(_ i: Int) -> CGFloat { min(0.22, max(0.09, devY[i] * 3)) }
    var placedIdx: [Int] { (0..<4).filter { placed[$0] } }
}

final class CalibrationModel: ObservableObject {
    enum Placing { case thumb, finger(Int) }

    private struct Stored: Codable {
        var cx: [Double]; var cy: [Double]; var devY: [Double]
        var thumbX: Double; var thumbY: Double
    }
    private struct Snapshot {
        var layout: FingerLayout
        var thumb: CGPoint; var thumbPlaced: Bool
    }

    private static let storeKey = "chordCalibration.v4"
    private static let learnKey = "chordCalibration.learning"
    static let defaultThumb = CGPoint(x: 0.14, y: 0.88)

    @Published private(set) var layout: FingerLayout
    @Published private(set) var thumbCenter: CGPoint
    @Published private(set) var thumbPlaced: Bool = true
    @Published var isLearning: Bool {
        didSet { UserDefaults.standard.set(isLearning, forKey: Self.learnKey) }
    }

    /// Calibration accepts touches much farther from the zones.
    var looseHitTest = false
    /// While set, ANY touch is assigned to this target (the "one big area" placement steps).
    var placing: Placing? = nil

    private var calibrating = false
    private var backup: Snapshot?

    init() {
        isLearning = UserDefaults.standard.object(forKey: Self.learnKey) as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let s = try? JSONDecoder().decode(Stored.self, from: data),
           s.cx.count == 4, s.cy.count == 4, s.devY.count == 4 {
            layout = FingerLayout(cx: s.cx.map { CGFloat($0) }, cy: s.cy.map { CGFloat($0) },
                                  devY: s.devY.map { CGFloat($0) })
            thumbCenter = CGPoint(x: s.thumbX, y: s.thumbY)
        } else {
            layout = .defaults()
            thumbCenter = Self.defaultThumb
        }
        constrain(&layout); constrainThumb()
    }

    func reset() {
        calibrating = false; backup = nil; placing = nil
        layout = .defaults()
        thumbCenter = Self.defaultThumb
        thumbPlaced = true
        save()
    }

    // MARK: Calibration session lifecycle

    func beginCalibration() {
        backup = Snapshot(layout: layout, thumb: thumbCenter, thumbPlaced: thumbPlaced)
        calibrating = true
        layout.placed = Array(repeating: false, count: 4)
        thumbPlaced = false
    }
    func endCalibration() {
        calibrating = false; placing = nil; backup = nil
        save()
    }
    func cancelCalibration() {
        if let b = backup {
            layout = b.layout; thumbCenter = b.thumb; thumbPlaced = b.thumbPlaced
        }
        calibrating = false; placing = nil; backup = nil
    }

    func placeThumb(at p: CGPoint) {
        thumbCenter = p; thumbPlaced = true
        constrainThumb(); save()
    }
    func place(finger: Int, at p: CGPoint) {
        let i = finger.trailingZeroBitCount
        guard i >= 0 && i < 4 else { return }
        mutate { L in
            L.cx[i] = p.x; L.cy[i] = p.y; L.devY[i] = 0.045; L.placed[i] = true
        }
    }

    // MARK: Geometry (normalized 0...1 in panel space)

    /// One optional rect per finger (nil = not placed yet). Widths follow the spacing
    /// between neighbouring placed fingers.
    func rects() -> [CGRect?] {
        let L = layout
        let idx = L.placedIdx
        var out = [CGRect?](repeating: nil, count: 4)
        for (k, i) in idx.enumerated() {
            let x = L.cx[i]
            let prev: CGFloat? = k > 0 ? L.cx[idx[k - 1]] : nil
            let next: CGFloat? = k < idx.count - 1 ? L.cx[idx[k + 1]] : nil
            var left: CGFloat, right: CGFloat
            switch (prev, next) {
            case let (p?, n?): left = (p + x) / 2;       right = (x + n) / 2
            case let (p?, nil): left = (p + x) / 2;      right = x + (x - p) / 2
            case let (nil, n?): left = x - (n - x) / 2;  right = (x + n) / 2
            default:            left = x - 0.075;        right = x + 0.075
            }
            left = max(left, 0); right = min(right, 1)
            let hh = L.halfH(i)
            out[i] = CGRect(x: left, y: L.cy[i] - hh, width: max(right - left, 0.05), height: hh * 2)
        }
        return out
    }

    /// Nearest placed zone (generous radius so a drifted hand still registers).
    func zoneID(at p: CGPoint) -> Int? {
        switch placing {
        case .thumb?:         return 16
        case .finger(let f)?: return f
        case nil:             break
        }
        var best: (idx: Int, d: CGFloat)?
        for (i, maybe) in rects().enumerated() {
            guard let r = maybe else { continue }
            let dx = (p.x - r.midX) / (r.width / 2)
            let dy = (p.y - r.midY) / (r.height / 2)
            let d = hypot(dx, dy)
            if best == nil || d < best!.d { best = (i, d) }
        }
        guard let b = best, b.d < (looseHitTest ? 8 : 2.2) else { return nil }
        return 1 << b.idx
    }

    // MARK: Learning

    /// Learn from one committed chord.
    /// - correct: pair each landing with the zone it hit.
    /// - wrong: if the finger count matches the expected chord, pair landings left→right
    ///   with the expected fingers (lets the layout recover when it starts far off).
    func learn(landings: [Landing], expectedMask: Int, correct: Bool,
               boost: CGFloat = 1, force: Bool = false) {
        guard isLearning || force, !landings.isEmpty else { return }
        var pairs: [(Int, CGPoint)] = []
        let rate: CGFloat

        if correct {
            pairs = landings.map { ($0.zone.trailingZeroBitCount, $0.point) }
            rate = 0.15 * boost
        } else {
            let want = (0..<4).filter { expectedMask & (1 << $0) != 0 }
            guard want.count == landings.count else { return }
            let sorted = landings.sorted { $0.point.x < $1.point.x }
            pairs = Array(zip(want, sorted.map { $0.point }))
            rate = 0.08 * boost
        }

        let maxOff: CGFloat = force ? 0.45 : 0.25
        let learned = pairs
        mutate { L in
            for (i, p) in learned where i >= 0 && i < 4 && L.placed[i] {
                guard abs(p.x - L.cx[i]) < maxOff else { continue }   // ignore wild touches
                L.cx[i] += (p.x - L.cx[i]) * rate
                L.cy[i] += (p.y - L.cy[i]) * rate
                L.devY[i] += (abs(p.y - L.cy[i]) - L.devY[i]) * 0.10
            }
        }
    }

    func learnThumb(globalPoint g: CGPoint, panel: CGRect, force: Bool = false) {
        guard isLearning || force, thumbPlaced, panel.width > 1, panel.height > 1 else { return }
        let rate: CGFloat = force ? 0.25 : 0.10
        let p = CGPoint(x: (g.x - panel.minX) / panel.width, y: (g.y - panel.minY) / panel.height)
        thumbCenter.x += (p.x - thumbCenter.x) * rate
        thumbCenter.y += (p.y - thumbCenter.y) * rate
        constrainThumb(); save()
    }

    // MARK: Internals

    private func mutate(_ f: (inout FingerLayout) -> Void) {
        var L = layout
        f(&L); constrain(&L)
        layout = L
        save()
    }

    private func constrain(_ L: inout FingerLayout) {
        let gap: CGFloat = 0.06
        let idx = L.placedIdx
        for i in 0..<4 {
            L.devY[i] = min(max(L.devY[i], 0.03), 0.0733)
            L.cx[i]   = min(max(L.cx[i], 0.05), 0.95)
        }
        if idx.count > 1 {
            for k in 1..<idx.count { L.cx[idx[k]] = max(L.cx[idx[k]], L.cx[idx[k-1]] + gap) }
            if let last = idx.last, L.cx[last] > 0.95 { L.cx[last] = 0.95 }
            for k in stride(from: idx.count - 2, through: 0, by: -1) {
                L.cx[idx[k]] = min(L.cx[idx[k]], L.cx[idx[k+1]] - gap)
            }
        }
        for i in 0..<4 {
            let hh = L.halfH(i)
            L.cy[i] = min(max(L.cy[i], hh + 0.09), 1 - hh)   // keep clear of the top bar
        }
    }

    private func constrainThumb() {
        thumbCenter.x = min(max(thumbCenter.x, 0.11), 0.89)
        thumbCenter.y = min(max(thumbCenter.y, 0.10), 0.92)
    }

    private func save() {
        guard !calibrating else { return }   // only persist finished calibrations
        let s = Stored(cx: layout.cx.map(Double.init), cy: layout.cy.map(Double.init),
                       devY: layout.devY.map(Double.init),
                       thumbX: Double(thumbCenter.x), thumbY: Double(thumbCenter.y))
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: Self.storeKey) }
    }
}

// MARK: - Standalone Calibration Session
//
// Starts with one big blank touch area. You place the thumb first, then — with your
// thumb resting on its button — each finger where it naturally sits. Zones appear where
// you touch. The remaining steps refine every chord.

final class CalibrationSession: ObservableObject {
    enum Step: Equatable {
        case placeThumb
        case placeFinger(Int)      // finger bit
        case chord(Int)            // mask
        case thumbTap
    }

    private let calibration: CalibrationModel

    @Published private(set) var steps: [Step] = []
    @Published private(set) var index: Int = 0
    @Published var wrongFlash = false

    var finished: Bool { index >= steps.count }
    var current: Step? { index < steps.count ? steps[index] : nil }
    var progress: Double { steps.isEmpty ? 0 : Double(index) / Double(steps.count) }
    var isPlacing: Bool {
        switch current {
        case .placeThumb?, .placeFinger?: return true
        default: return false
        }
    }

    init(calibration: CalibrationModel) {
        self.calibration = calibration
        calibration.beginCalibration()
        build()
    }

    func restart() {
        calibration.beginCalibration()
        build()
    }

    func cancelIfUnfinished() {
        if !finished { calibration.cancelCalibration() }
        calibration.placing = nil
    }

    private func build() {
        var s: [Step] = [.placeThumb]
        s += [1, 2, 4, 8].map { Step.placeFinger($0) }
        for _ in 0..<2 { s += [1, 2, 4, 8].shuffled().map { Step.chord($0) } }
        s += [3, 5, 9, 6, 10, 12].shuffled().map { Step.chord($0) }
        s += [7, 14, 11, 13, 15].shuffled().map { Step.chord($0) }
        s += [Step.thumbTap, Step.thumbTap]
        steps = s
        index = 0
        updatePlacing()
    }

    private func updatePlacing() {
        switch current {
        case .placeThumb?:        calibration.placing = .thumb
        case .placeFinger(let f)?: calibration.placing = .finger(f)
        default:                  calibration.placing = nil
        }
    }

    private func advance() {
        index += 1
        haptic(.light)
        if finished { calibration.endCalibration() } else { updatePlacing() }
    }

    private func reject() {
        haptic(.rigid)
        wrongFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.wrongFlash = false }
    }

    func handleChord(mask: Int, landings: [Landing]) {
        guard let step = current, let first = landings.first else { return }
        switch step {
        case .placeThumb:
            withAnimation(.easeOut(duration: 0.25)) { calibration.placeThumb(at: first.point) }
            advance()

        case .placeFinger(let f):
            withAnimation(.easeOut(duration: 0.25)) { calibration.place(finger: f, at: first.point) }
            advance()

        case .chord(let want):
            let ok = mask == want
            calibration.learn(landings: landings, expectedMask: want, correct: ok,
                              boost: 1.6, force: true)
            if ok { advance() } else { reject() }

        case .thumbTap:
            break
        }
    }

    func handleThumbTap() {
        guard case .thumbTap? = current else { return }
        advance()
    }
}


// MARK: - Game Engine

enum GamePhase { case intro, playing, levelComplete, gameComplete, calibrating }

class GameEngine: ObservableObject {
    @Published var phase: GamePhase = .intro
    @Published var currentLevelIndex: Int = 0
    @Published var target: String = ""       // letter or full sentence
    @Published var typed:  String = ""       // accumulates chars including spaces
    @Published var score:  Int = 0
    @Published var streak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var timeRemaining: Double = 0
    @Published var feedback: FeedbackKind? = nil
    @Published var levelUnlocked: Int = 40
    @Published var wrongShake: Bool = false
    @Published var wrongChar: String = ""

    enum FeedbackKind { case correct, wrong, levelUp }

    /// Called for every letter chord with whether it matched, and the chord that was expected.
    /// Used by the calibration model to learn finger positions.
    var onResult: ((_ correct: Bool, _ expectedMask: Int) -> Void)?

    private var timer: Timer?
    private var usedTargets: [String] = []

    var level: GameLevel { gameLevels[currentLevelIndex] }

    var isLetterMode: Bool {
        if case .letters = level.mode { return true }
        return false
    }
    var isWordMode: Bool {
        if case .words = level.mode { return true }
        return false
    }
    var isSentenceMode: Bool {
        if case .sentences = level.mode { return true }
        return false
    }

    // For sentence/word mode: what char is next expected
    var nextExpected: String {
        guard typed.count < target.count else { return "" }
        return String(target[target.index(target.startIndex, offsetBy: typed.count)])
    }

    var hintForTarget: (mask: Int, layer2: Bool)? {
        guard level.showHint else { return nil }
        if isLetterMode { return chordFor(target) }
        if isWordMode || isSentenceMode { return chordFor(nextExpected) }
        return nil
    }

    /// The chord the player should be pressing right now (ignores showHint).
    var expectedChord: (mask: Int, layer2: Bool)? {
        isLetterMode ? chordFor(target) : chordFor(nextExpected)
    }

    var progress: Double {
        guard level.targetCount > 0 else { return 0 }
        return Double(score) / Double(level.targetCount)
    }

    func startLevel(_ index: Int) {
        currentLevelIndex = index
        score  = 0; streak = 0; typed = ""; wrongChar = ""
        usedTargets = []
        timeRemaining = level.timeLimit ?? 0
        phase = .playing
        pickTarget()
        if level.timeLimit != nil { startTimer() }
    }

    func restart() { startLevel(currentLevelIndex) }

    private func pickTarget() {
        switch level.mode {
        case .letters(let pool):
            let filtered = pool.count > 1 ? pool.filter { $0 != target } : pool
            target = filtered.randomElement()!
            typed  = ""
        case .words(let pool):
            let unused = pool.filter { !usedTargets.contains($0) }
            target = (unused.isEmpty ? pool : unused).randomElement()!
            typed  = ""
        case .sentences(let pool):
            let unused = pool.filter { !usedTargets.contains($0) }
            target = (unused.isEmpty ? pool : unused).randomElement()!
            typed  = ""
        }
    }

    // MARK: Input handlers

    func receiveLetter(_ letter: String) {
        guard phase == .playing else { return }
        wrongChar = ""
        let expected = expectedChord?.mask ?? 0   // capture before the target changes

        if isLetterMode {
            if letter == target { onResult?(true, expected); correct() }
            else { onResult?(false, expected); wrong(letter) }
            return
        }

        // Word / sentence: append if matches next expected char
        if typed.count < target.count {
            if letter == nextExpected {
                onResult?(true, expected)
                typed += letter
                checkWordOrSentenceComplete()
            } else {
                onResult?(false, expected)
                wrong(letter)
            }
        }
    }

    func receiveSpace() {
        guard phase == .playing else { return }
        guard isWordMode || isSentenceMode else { return }

        if typed.count < target.count && nextExpected == " " {
            onResult?(true, 1)
            typed += " "
            checkWordOrSentenceComplete()
        } else if isWordMode && typed == target {
            // Allow trailing space to confirm word
            onResult?(true, 1)
            correct()
        } else if isSentenceMode && typed.count < target.count {
            wrong(" ")
        }
    }

    func receiveBackspace() {
        guard phase == .playing else { return }
        guard isWordMode || isSentenceMode else { return }
        if !typed.isEmpty { onResult?(true, 2); typed.removeLast(); wrongChar = "" }
    }

    private func checkWordOrSentenceComplete() {
        if typed == target { correct() }
    }

    private func correct() {
        score  += 1
        streak += 1
        if streak > bestStreak { bestStreak = streak }
        showFeedback(.correct)
        if score >= level.targetCount {
            completeLevel()
        } else {
            usedTargets.append(target)
            pickTarget()
        }
    }

    private func wrong(_ ch: String = "") {
        streak   = 0
        wrongChar = ch
        showFeedback(.wrong)
        withAnimation { wrongShake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation { self.wrongShake = false }
        }
    }

    private func completeLevel() {
        timer?.invalidate(); timer = nil
        showFeedback(.levelUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.phase = self.level.number == gameLevels.last!.number
                ? .gameComplete : .levelComplete
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.timeRemaining = max(0, self.timeRemaining - 0.1)
            if self.timeRemaining == 0 { self.completeLevel() }
        }
    }

    private func showFeedback(_ kind: FeedbackKind) {
        feedback = kind
        DispatchQueue.main.asyncAfter(deadline: .now() + (kind == .levelUp ? 0.7 : 0.28)) {
            self.feedback = nil
        }
    }

    deinit { timer?.invalidate() }
}

// MARK: - Chord Engine

class ChordEngine: NSObject, ObservableObject {
    @Published var activeMask: Int = 0
    @Published var layer2Active: Bool = false
    @Published var flashKey: String? = nil
    @Published var thumbHeld: Bool = false

    var onLetter:    ((String) -> Void)?
    var onSpace:     (() -> Void)?
    var onBackspace: (() -> Void)?

    /// Calibration hooks. When `onRawChord` is set, chords are delivered raw
    /// (mask + landing points) instead of being turned into letters.
    var onRawChord:  ((Int, [Landing]) -> Void)?
    var onThumbTap:  (() -> Void)?

    /// Landing points of the chord currently being delivered to onLetter.
    var pendingLandings: [Landing] = []

    var previewLabel: String {
        guard activeMask != 0 else { return "" }
        if thumbHeld, let s = thumbChords[activeMask] { return specialDisplay(s) }
        if let ch = (layer2Active ? layer2 : layer1)[activeMask] { return ch }
        var p: [String] = []
        if activeMask & 1 != 0 { p.append("I") }
        if activeMask & 2 != 0 { p.append("M") }
        if activeMask & 4 != 0 { p.append("R") }
        if activeMask & 8 != 0 { p.append("P") }
        return p.joined(separator: "+")
    }

    func updateMask(_ mask: Int) { activeMask = mask }

    func commit(mask: Int, landings: [Landing] = []) {
        guard mask != 0 else { return }
        // Calibration gets raw chords (with landing points and thumb state)
        if let raw = onRawChord { raw(mask, landings); return }
        if thumbHeld, let special = thumbChords[mask] {
            flash(specialDisplay(special)); haptic(.medium)
            pendingLandings = landings
            switch special {
            case "space":      onSpace?()
            case "backspace":  onBackspace?()
            default: break
            }
            pendingLandings = []
            return
        }
        if let ch = (layer2Active ? layer2 : layer1)[mask] {
            flash(ch); haptic(.light)
            pendingLandings = landings
            onLetter?(ch)
            pendingLandings = []
        } else {
            haptic(.rigid); flash("?")
        }
    }

    func toggleLayer() {
        layer2Active.toggle(); haptic(.rigid); flash(layer2Active ? "L2":"L1")
        onThumbTap?()
    }
    func thumbSpaceAlone() {
        guard onRawChord == nil else { return }
        flash("⎵"); haptic(.medium); onSpace?()
    }

    private func flash(_ t: String) {
        withAnimation(.easeOut(duration: 0.06)) { flashKey = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation { self.flashKey = nil }
        }
    }

    func specialDisplay(_ s: String) -> String {
        switch s {
        case "space": return "⎵"; case "backspace": return "⌫"
        case "newline": return "↵"; case "deleteword": return "⌫⌫"
        default: return s
        }
    }
}

// MARK: - Multi-Touch Tracker (calibration-aware)

class ChordTracker: UIView {
    var onMaskChange: ((Int) -> Void)?
    var onCommit:     ((Int, [Landing]) -> Void)?
    var calibration:  CalibrationModel?
    var panelFrame:   CGRect = .zero          // global coords of the chord panel

    private var activeTouches: [UITouch: Int] = [:]
    private var landings: [Landing] = []
    private var peakMask: Int = 0
    private var everMulti = false
    private let singleRelease: TimeInterval = 0.040
    private let multiRelease:  TimeInterval = 0.110
    private var releaseTimer: Timer?

    private func norm(_ t: UITouch) -> CGPoint {
        let g = t.location(in: nil)   // window coordinates
        return CGPoint(x: (g.x - panelFrame.minX) / max(panelFrame.width, 1),
                       y: (g.y - panelFrame.minY) / max(panelFrame.height, 1))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTimer?.invalidate(); releaseTimer = nil
        for t in touches {
            let p = norm(t)
            if let z = calibration?.zoneID(at: p) {
                activeTouches[t] = z
                landings.append(Landing(zone: z, point: p))
            }
        }
        let cur = currentMask()
        if cur.nonzeroBitCount > 1 { everMulti = true }
        if cur.nonzeroBitCount > peakMask.nonzeroBitCount { peakMask = cur }
        onMaskChange?(cur)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var changed = false
        for t in touches {
            if let z = calibration?.zoneID(at: norm(t)) {
                let old = activeTouches[t] ?? 0
                if old != z { activeTouches[t] = z; changed = true }
            }
        }
        if changed {
            let cur = currentMask()
            if cur.nonzeroBitCount > 1 { everMulti = true }
            if cur.nonzeroBitCount > peakMask.nonzeroBitCount { peakMask = cur }
            onMaskChange?(cur)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { activeTouches.removeValue(forKey: t) }
        onMaskChange?(currentMask()); scheduleCommit()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetGesture(); onMaskChange?(0)
    }
    private func scheduleCommit() {
        guard activeTouches.isEmpty else { return }
        let d = everMulti ? multiRelease : singleRelease
        releaseTimer?.invalidate()
        releaseTimer = Timer.scheduledTimer(withTimeInterval: d, repeats: false) { [weak self] _ in
            guard let self, self.activeTouches.isEmpty else { return }
            let mask = self.peakMask, samples = self.landings
            self.resetGesture()
            if mask != 0 { self.onCommit?(mask, samples) }
        }
    }
    private func resetGesture() {
        activeTouches.removeAll(); landings.removeAll()
        peakMask = 0; everMulti = false
        releaseTimer?.invalidate(); releaseTimer = nil
    }
    private func currentMask() -> Int { activeTouches.values.reduce(0, |) }
    override var isMultipleTouchEnabled: Bool { get { true } set {} }
}

struct ChordSurface: UIViewRepresentable {
    var calibration: CalibrationModel
    var panelFrame: CGRect
    var onMaskChange: (Int) -> Void
    var onCommit:     (Int, [Landing]) -> Void
    func makeUIView(context: Context) -> ChordTracker {
        let v = ChordTracker(); v.isMultipleTouchEnabled = true; v.backgroundColor = .clear; return v
    }
    func updateUIView(_ v: ChordTracker, context: Context) {
        v.calibration = calibration; v.panelFrame = panelFrame
        v.onMaskChange = onMaskChange; v.onCommit = onCommit
    }
}

// MARK: - Finger Zone Models

struct FingerZone: Identifiable { let id: Int; let name: String; let color: Color }

let fingerZones: [FingerZone] = [
    FingerZone(id: 1, name: "Index",  color: Color(red: 0.94, green: 0.72, blue: 0.18)),
    FingerZone(id: 2, name: "Middle", color: Color(red: 0.11, green: 0.72, blue: 0.50)),
    FingerZone(id: 4, name: "Ring",   color: Color(red: 0.22, green: 0.54, blue: 0.87)),
    FingerZone(id: 8, name: "Pinky",  color: Color(red: 0.55, green: 0.45, blue: 0.90)),
]

struct RoundedCornerShape: InsettableShape {
    var corners: UIRectCorner; var radius: CGFloat; var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect.insetBy(dx: insetAmount, dy: insetAmount),
                          byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
    func inset(by amount: CGFloat) -> RoundedCornerShape { var s = self; s.insetAmount += amount; return s }
}

// MARK: - Zone View

struct FingerZoneView: View {
    let zone: FingerZone
    let isActive: Bool
    let isHinted: Bool
    let roundedCorners: UIRectCorner

    var body: some View {
        ZStack {
            RoundedCornerShape(corners: roundedCorners, radius: 16)
                .fill(isActive ? zone.color.opacity(0.28)
                      : isHinted ? zone.color.opacity(0.13)
                      : zone.color.opacity(0.07))
            RoundedCornerShape(corners: roundedCorners, radius: 16)
                .strokeBorder(zone.color.opacity(isActive ? 0.85 : isHinted ? 0.55 : 0.18),
                              lineWidth: isActive ? 2.0 : isHinted ? 1.5 : 0.5)
            Text(zone.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(zone.color.opacity(isActive ? 1.0 : isHinted ? 0.65 : 0.28))
                .tracking(0.6)
        }
        .scaleEffect(isActive ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.04), value: isActive)
        .overlay(
            RoundedCornerShape(corners: roundedCorners, radius: 16)
                .strokeBorder(zone.color.opacity(isHinted ? 0.40 : 0), lineWidth: 3)
                .scaleEffect(isHinted ? 1.04 : 1.0)
                .animation(isHinted
                    ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                    : .default, value: isHinted)
        )
    }
}

// MARK: - Thumb Button

struct ThumbButton: View {
    @ObservedObject var engine: ChordEngine
    let onTap: () -> Void; let onHold: () -> Void
    var onTouch: ((CGPoint) -> Void)? = nil      // global press location (for calibration)
    let color = Color(red: 0.85, green: 0.38, blue: 0.22)
    @State private var holdTimer: Timer?
    @State private var holdFired = false
    @State private var isPressed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(isPressed ? color.opacity(0.28) : color.opacity(0.08))
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(color.opacity(isPressed ? 0.75 : 0.20), lineWidth: isPressed ? 1.5 : 0.5)
            VStack(spacing: 3) {
                Text("Thumb")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color.opacity(isPressed ? 1.0 : 0.55))
                Text(engine.thumbHeld ? "I=spc  M=⌫  R=↵" : "tap=layer · hold=spc")
                    .font(.system(size: 9)).foregroundColor(color.opacity(engine.thumbHeld ? 0.70 : 0.30))
            }
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.05), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true; holdFired = false
                    engine.thumbHeld = true; haptic(.medium)
                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        holdFired = true; onHold(); haptic(.heavy)
                    }
                }
                .onEnded { v in
                    isPressed = false; engine.thumbHeld = false
                    holdTimer?.invalidate(); holdTimer = nil
                    if !holdFired { onTap() }
                    holdFired = false
                    onTouch?(v.startLocation)
                }
        )
    }
}

// MARK: - Chord Input Panel (adaptive layout)

struct ChordInputPanel: View {
    @ObservedObject var engine: ChordEngine
    @ObservedObject var calibration: CalibrationModel
    var hintMask:   Int  = 0
    var hintLayer2: Bool = false
    var forceLearning: Bool = false     // true inside the calibration screen
    var showBigArea:   Bool = false     // calibration placement: one big blank touch area

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let panelFrame = geo.frame(in: .global)
            let thumbW: CGFloat = W * 0.22
            let thumbH: CGFloat = H * 0.17
            let rects = calibration.rects()
            let tc = calibration.thumbCenter

            ZStack(alignment: .topLeading) {
                ChordSurface(calibration: calibration,
                             panelFrame: panelFrame,
                             onMaskChange: { engine.updateMask($0) },
                             onCommit:     { engine.commit(mask: $0, landings: $1) })
                    .frame(width: W, height: H).ignoresSafeArea()

                if showBigArea {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                        .foregroundColor(Color(white: 0.22))
                        .frame(width: W - 8, height: H - 8)
                        .offset(x: 4, y: 4)
                        .allowsHitTesting(false)
                }

                ForEach(0..<4, id: \.self) { idx in
                    if let r = rects[idx] {
                        FingerZoneView(zone: fingerZones[idx],
                                       isActive: engine.activeMask & fingerZones[idx].id != 0,
                                       isHinted: hintMask & fingerZones[idx].id != 0,
                                       roundedCorners: .allCorners)
                            .frame(width: max(r.width * W - 4, 10), height: r.height * H)
                            .offset(x: r.minX * W + 2, y: r.minY * H)
                            .animation(.easeOut(duration: 0.15), value: r)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }

                if calibration.thumbPlaced {
                    ThumbButton(engine: engine,
                                onTap:  { engine.toggleLayer() },
                                onHold: { engine.thumbSpaceAlone() },
                                onTouch: { calibration.learnThumb(globalPoint: $0, panel: panelFrame,
                                                                  force: forceLearning) })
                        .frame(width: thumbW, height: thumbH)
                        .offset(x: tc.x * W - thumbW / 2, y: tc.y * H - thumbH / 2)
                        .animation(.easeOut(duration: 0.25), value: tc)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }

                // Layer / preview status
                HStack(spacing: 6) {
                    if calibration.isLearning || forceLearning {
                        Text("ADAPT")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.22, green: 0.75, blue: 0.50).opacity(0.8))
                    }
                    if engine.thumbHeld {
                        Text("THUMB")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.85, green: 0.38, blue: 0.22).opacity(0.9))
                    }
                    if hintLayer2 && !engine.layer2Active {
                        Text("tap thumb → L2")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18).opacity(0.75))
                    }
                    Text(engine.layer2Active ? "L2" : "L1")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(engine.layer2Active
                            ? Color(red: 0.94, green: 0.72, blue: 0.18) : Color(white: 0.28))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(white: 0.10)).clipShape(RoundedRectangle(cornerRadius: 5))
                    Text(engine.previewLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.28))
                        .frame(minWidth: 28, alignment: .trailing)
                }
                .padding(.trailing, 12).padding(.bottom, 8)
                .frame(width: W, height: H, alignment: .bottomTrailing)
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Level Select

struct LevelSelectView: View {
    @ObservedObject var game: GameEngine
    let onSelect: (Int) -> Void
    let onCalibrate: () -> Void

    // Section order
    private let sections = ["Layer 1", "Layer 2", "Both Layers", "Words", "Sentences"]
    private let sectionColors: [String: Color] = [
        "Layer 1":    Color(red: 0.22, green: 0.75, blue: 0.50),
        "Layer 2":    Color(red: 0.94, green: 0.72, blue: 0.18),
        "Both Layers":Color(red: 0.55, green: 0.45, blue: 0.90),
        "Words":      Color(red: 0.22, green: 0.54, blue: 0.87),
        "Sentences":  Color(red: 0.85, green: 0.38, blue: 0.22),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text("CHORD TRAINER")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                        .tracking(3)
                    Spacer()
                    Button(action: onCalibrate) {
                        HStack(spacing: 4) {
                            Image(systemName: "scope").font(.system(size: 9))
                            Text("CALIBRATE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundColor(Color(red: 0.22, green: 0.75, blue: 0.50))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(white: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    if game.bestStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.20))
                            Text("\(game.bestStreak)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.20))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)

                // Sections as horizontal rows
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(sections, id: \.self) { section in
                            let levelsInSection = gameLevels.filter { $0.section == section }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(sectionColors[section] ?? .white)
                                        .frame(width: 3, height: 14)
                                    Text(section.uppercased())
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(sectionColors[section]?.opacity(0.8) ?? Color(white: 0.4))
                                        .tracking(2)
                                }
                                .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(levelsInSection, id: \.number) { lvl in
                                            let unlocked = lvl.number <= game.levelUnlocked
                                            LevelCard(level: lvl, unlocked: unlocked,
                                                      accentColor: sectionColors[section] ?? .white)
                                                .onTapGesture { if unlocked { onSelect(lvl.number - 1) } }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

struct LevelCard: View {
    let level: GameLevel; let unlocked: Bool; let accentColor: Color

    var modeIcon: String {
        switch level.mode {
        case .letters:   return "character.cursor.ibeam"
        case .words:     return "text.word.spacing"
        case .sentences: return "text.alignleft"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(level.number)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(unlocked ? accentColor : Color(white: 0.22))
                Spacer()
                Image(systemName: unlocked ? modeIcon : "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(unlocked ? accentColor.opacity(0.6) : Color(white: 0.22))
                if let t = level.timeLimit {
                    Text("\(Int(t))s")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(red: 0.85, green: 0.38, blue: 0.22).opacity(0.8))
                }
            }
            Text(level.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(unlocked ? Color(white: 0.85) : Color(white: 0.28))
                .lineLimit(1)
            Text(level.description)
                .font(.system(size: 9))
                .foregroundColor(unlocked ? Color(white: 0.35) : Color(white: 0.18))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("\(level.targetCount) \(unitLabel)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(white: 0.22))
        }
        .padding(11)
        .frame(width: 148, height: 110)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.09))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(unlocked ? accentColor.opacity(0.22) : Color(white: 0.09), lineWidth: 0.5))
        )
        .opacity(unlocked ? 1.0 : 0.45)
    }

    var unitLabel: String {
        switch level.mode {
        case .letters:   return "letters"
        case .words:     return "words"
        case .sentences: return "sentences"
        }
    }
}

// MARK: - Playing View

struct PlayingView: View {
    @ObservedObject var game: GameEngine
    @ObservedObject var engine: ChordEngine
    @ObservedObject var calibration: CalibrationModel
    let onMenu: () -> Void

    var hint: (mask: Int, layer2: Bool)? { game.hintForTarget }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let infoH: CGFloat = H * 0.42

            ZStack(alignment: .topLeading) {
                Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()

                // Feedback bg
                if let fb = game.feedback {
                    feedbackColor(fb).ignoresSafeArea().allowsHitTesting(false)
                        .transition(.opacity).animation(.easeOut(duration: 0.12), value: game.feedback != nil)
                }

                // Chord panel — the whole screen is the touch area, so fingers
                // can rest in the top half when the thumb is held.
                ChordInputPanel(engine: engine,
                                calibration: calibration,
                                hintMask:   hint?.mask   ?? 0,
                                hintLayer2: hint?.layer2 ?? false)
                    .frame(width: W, height: H)

                // Info area
                VStack(spacing: 0) {
                    // Top bar
                    HStack(spacing: 10) {
                        Button(action: onMenu) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.30))
                        }
                        // Adaptive layout toggle
                        Button { calibration.isLearning.toggle(); haptic(.light) } label: {
                            Image(systemName: "scope")
                                .font(.system(size: 13))
                                .foregroundColor(calibration.isLearning
                                    ? Color(red: 0.22, green: 0.75, blue: 0.50) : Color(white: 0.30))
                        }
                        // Reset layout
                        Button { calibration.reset(); haptic(.rigid) } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.30))
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(game.level.section.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(Color(white: 0.28))
                                .tracking(1.5)
                            Text(game.level.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.55))
                        }
                        Spacer()
                        if game.level.timeLimit != nil {
                            Text(String(format: "%.0f", max(0, game.timeRemaining)))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(game.timeRemaining < 10
                                    ? Color(red: 1.0, green: 0.35, blue: 0.35) : Color(white: 0.45))
                        }
                        if game.streak > 1 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill").font(.system(size: 10))
                                Text("\(game.streak)").font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.20))
                        }
                        Text("\(game.score)/\(game.level.targetCount)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.40))
                    }
                    .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 6)

                    // Progress bar
                    GeometryReader { pg in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(white: 0.11)).frame(height: 3)
                            Capsule()
                                .fill(Color(red: 0.22, green: 0.75, blue: 0.50))
                                .frame(width: pg.size.width * game.progress, height: 3)
                                .animation(.spring(response: 0.3), value: game.score)
                        }
                    }
                    .frame(height: 3).padding(.horizontal, 14)
                    .allowsHitTesting(false)

                    Spacer()
                    GameTargetView(game: game)
                        .modifier(ShakeModifier(shaking: game.wrongShake))
                        .allowsHitTesting(false)
                    Spacer()
                }
                .frame(width: W, height: infoH)

                // Engine flash
                if let flash = engine.flashKey {
                    Text(flash)
                        .font(.system(size: flash.count > 2 ? 40 : 80,
                                      weight: .black, design: .monospaced))
                        .foregroundColor(.white).opacity(0.55)
                        .allowsHitTesting(false)
                        .frame(width: W, height: H)
                        .offset(y: -H * 0.06)
                }
            }
        }
    }

    func feedbackColor(_ fb: GameEngine.FeedbackKind) -> Color {
        switch fb {
        case .correct:  return Color(red: 0.10, green: 0.60, blue: 0.35).opacity(0.16)
        case .wrong:    return Color(red: 0.80, green: 0.15, blue: 0.15).opacity(0.16)
        case .levelUp:  return Color(red: 0.94, green: 0.72, blue: 0.18).opacity(0.18)
        }
    }
}

// MARK: - Calibration View (standalone mode)

struct CalibrationView: View {
    @ObservedObject var engine: ChordEngine
    @ObservedObject var calibration: CalibrationModel
    @StateObject private var session: CalibrationSession
    let onExit: () -> Void

    init(engine: ChordEngine, calibration: CalibrationModel, onExit: @escaping () -> Void) {
        _engine = ObservedObject(wrappedValue: engine)
        _calibration = ObservedObject(wrappedValue: calibration)
        _session = StateObject(wrappedValue: CalibrationSession(calibration: calibration))
        self.onExit = onExit
    }

    private var hintMask: Int {
        if case .chord(let m)? = session.current { return m }
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height

            ZStack(alignment: .topLeading) {
                Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()

                if session.wrongFlash {
                    Color(red: 0.80, green: 0.15, blue: 0.15).opacity(0.14)
                        .ignoresSafeArea().allowsHitTesting(false)
                }

                if session.finished {
                    finishedView.frame(width: W, height: H)
                } else {
                    // The whole screen is the touch area, so fingers can rest anywhere.
                    ChordInputPanel(engine: engine,
                                    calibration: calibration,
                                    hintMask: hintMask,
                                    hintLayer2: false,
                                    forceLearning: true,
                                    showBigArea: session.isPlacing)
                        .frame(width: W, height: H)

                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Button(action: onExit) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.30))
                            }
                            Text("CALIBRATION")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 0.22, green: 0.75, blue: 0.50))
                                .tracking(2)
                            Spacer()
                            Text("\(session.index + 1)/\(session.steps.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(white: 0.40))
                        }
                        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 6)

                        GeometryReader { pg in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(white: 0.11)).frame(height: 3)
                                Capsule()
                                    .fill(Color(red: 0.22, green: 0.75, blue: 0.50))
                                    .frame(width: pg.size.width * session.progress, height: 3)
                                    .animation(.spring(response: 0.3), value: session.index)
                            }
                        }
                        .frame(height: 3).padding(.horizontal, 14)
                        .allowsHitTesting(false)
                    }
                    .frame(width: W)

                    // Prompt lives in the free left column so it never covers the finger zones.
                    promptView
                        .frame(width: W * 0.26, alignment: .leading)
                        .offset(x: 14, y: H * 0.16)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            calibration.looseHitTest = true
            engine.layer2Active = false
            engine.onRawChord = { mask, landings in
                session.handleChord(mask: mask, landings: landings)
            }
            engine.onThumbTap = {
                session.handleThumbTap()
                engine.layer2Active = false
            }
        }
        .onDisappear {
            session.cancelIfUnfinished()
            calibration.looseHitTest = false
            engine.onRawChord = nil
            engine.onThumbTap = nil
            engine.layer2Active = false
        }
    }

    // MARK: Prompts

    private func names(_ mask: Int) -> String {
        fingerZones.filter { mask & $0.id != 0 }.map { $0.name.uppercased() }.joined(separator: "\n+ ")
    }

    private func dots(_ mask: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(fingerZones) { z in
                Circle()
                    .fill(mask & z.id != 0 ? z.color : z.color.opacity(0.10))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(z.color.opacity(0.5), lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func promptBlock(title: String, sub: String, mask: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if mask != 0 { dots(mask) }
            Text(title)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundColor(Color(white: 0.92))
                .minimumScaleFactor(0.6)
            Text(sub)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.40))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var promptView: some View {
        switch session.current {
        case .placeThumb?:
            promptBlock(title: "THUMB",
                        sub: "Tap anywhere on the screen where your thumb rests. Your fingers will be placed relative to it.",
                        mask: 0)
        case .placeFinger(let f)?:
            promptBlock(title: names(f),
                        sub: "Rest your thumb on its button, then tap where this finger naturally sits — anywhere on screen",
                        mask: f)
        case .chord(let mask)?:
            promptBlock(title: names(mask), sub: "Press these together", mask: mask)
        case .thumbTap?:
            promptBlock(title: "THUMB", sub: "Tap the thumb button", mask: 0)
        case nil:
            EmptyView()
        }
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Text("CALIBRATED")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18)).tracking(3)
            Text("Your layout now matches your hand.")
                .font(.system(size: 13)).foregroundColor(Color(white: 0.50))
            Text("Leave the scope toggle on in-game to keep refining it.")
                .font(.system(size: 10)).foregroundColor(Color(white: 0.30))
            HStack(spacing: 10) {
                GameButton(label: "Defaults", color: Color(white: 0.18)) {
                    calibration.reset(); haptic(.rigid)
                }
                GameButton(label: "Redo", color: Color(red: 0.22, green: 0.38, blue: 0.65)) {
                    session.restart()
                }
                GameButton(label: "Done", color: Color(red: 0.18, green: 0.60, blue: 0.38), action: onExit)
            }
        }
        .padding(28)
    }
}

// MARK: - Target Display

struct GameTargetView: View {
    @ObservedObject var game: GameEngine

    var body: some View {
        Group {
            if game.isLetterMode {
                letterView
            } else if game.isWordMode {
                wordView
            } else {
                sentenceView
            }
        }
    }

    // ── Letter mode ───────────────────────────────────────────────────────────
    var letterView: some View {
        VStack(spacing: 6) {
            Text(game.target)
                .font(.system(size: 88, weight: .black, design: .monospaced))
                .foregroundColor(Color(white: 0.92))
                .id(game.target)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.75).combined(with: .opacity),
                    removal:   .opacity))
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: game.target)

            if let hint = game.hintForTarget {
                HStack(spacing: 4) {
                    if hint.layer2 {
                        Text("L2")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18).opacity(0.8))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color(white: 0.10)).clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(fingerLabel(hint.mask))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(white: 0.30))
                }
            }

            if !game.wrongChar.isEmpty {
                HStack(spacing: 4) {
                    Text("typed \(game.wrongChar)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                    Text("want \(game.target)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(red: 0.22, green: 0.75, blue: 0.50))
                }
            }
        }
    }

    // ── Word mode ─────────────────────────────────────────────────────────────
    var wordView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(Array(game.target.enumerated()), id: \.offset) { idx, ch in
                    Text(String(ch))
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundColor(idx < game.typed.count
                            ? Color(red: 0.22, green: 0.75, blue: 0.50)
                            : idx == game.typed.count
                                ? Color(white: 0.92)
                                : Color(white: 0.35))
                        .overlay(
                            Rectangle()
                                .fill(idx == game.typed.count
                                      ? Color(red: 0.94, green: 0.72, blue: 0.18)
                                      : .clear)
                                .frame(height: 2)
                                .offset(y: 24),
                            alignment: .bottom
                        )
                }
            }

            if let hint = game.hintForTarget, !game.nextExpected.isEmpty {
                HStack(spacing: 4) {
                    Text("next: \(game.nextExpected)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                    if hint.layer2 {
                        Text("L2").font(.system(size: 8, weight: .black))
                            .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18).opacity(0.7))
                    }
                    Text("· \(fingerLabel(hint.mask))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(white: 0.28))
                }
            }

            if !game.wrongChar.isEmpty {
                Text("✗ \(game.wrongChar)").font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
            }
        }
    }

    // ── Sentence mode ─────────────────────────────────────────────────────────
    var sentenceView: some View {
        VStack(spacing: 10) {
            // Full sentence with coloring — scrolls if too long
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(game.target.enumerated()), id: \.offset) { idx, ch in
                        let done    = idx < game.typed.count
                        let current = idx == game.typed.count
                        let disp    = ch == " " ? "·" : String(ch)
                        Text(disp)
                            .font(.system(size: ch == " " ? 14 : 22,
                                          weight: .black, design: .monospaced))
                            .foregroundColor(
                                done    ? Color(red: 0.22, green: 0.75, blue: 0.50) :
                                current ? Color(white: 0.95) :
                                          Color(white: 0.28))
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        current
                                            ? Color(red: 0.94, green: 0.72, blue: 0.18).opacity(0.25)
                                            : Color.clear
                                    )
                            )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 36)

            // Next char hint
            if !game.nextExpected.isEmpty, let hint = game.hintForTarget {
                let nextDisp = game.nextExpected == " " ? "SPACE" : game.nextExpected
                HStack(spacing: 6) {
                    Text("→ \(nextDisp)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.55))
                    if game.nextExpected != " " {
                        if hint.layer2 {
                            Text("L2").font(.system(size: 8, weight: .black))
                                .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18).opacity(0.7))
                        }
                        Text(fingerLabel(hint.mask))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(white: 0.30))
                    } else {
                        Text("Thumb+Index")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(white: 0.30))
                    }
                }
            }

            if !game.wrongChar.isEmpty {
                let w = game.wrongChar == " " ? "SPACE" : game.wrongChar
                Text("✗ \(w)").font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
            }
        }
    }

    func fingerLabel(_ mask: Int) -> String {
        var p: [String] = []
        if mask & 1 != 0 { p.append("Index") }
        if mask & 2 != 0 { p.append("Middle") }
        if mask & 4 != 0 { p.append("Ring") }
        if mask & 8 != 0 { p.append("Pinky") }
        return p.joined(separator:"+")
    }
}

struct ShakeModifier: ViewModifier {
    let shaking: Bool
    func body(content: Content) -> some View {
        content.offset(x: shaking ? -8 : 0)
            .animation(shaking ? .easeInOut(duration: 0.07).repeatCount(4, autoreverses: true) : .default,
                       value: shaking)
    }
}

// MARK: - Level Complete

struct LevelCompleteView: View {
    @ObservedObject var game: GameEngine
    let onNext: () -> Void; let onRetry: () -> Void; let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("COMPLETE").font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18)).tracking(3)
                Text(game.level.title).font(.system(size: 20, weight: .bold)).foregroundColor(Color(white: 0.80))
                HStack(spacing: 28) {
                    StatPill(label: "Score",  value: "\(game.score)")
                    StatPill(label: "Streak", value: "\(game.bestStreak)")
                }
                HStack(spacing: 10) {
                    GameButton(label: "Menu",  color: Color(white: 0.18), action: onMenu)
                    GameButton(label: "Retry", color: Color(red: 0.22, green: 0.38, blue: 0.65), action: onRetry)
                    if game.level.number < gameLevels.count {
                        GameButton(label: "Next →", color: Color(red: 0.18, green: 0.60, blue: 0.38), action: onNext)
                    }
                }
            }
            .padding(28)
        }
    }
}

struct StatPill: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .black, design: .monospaced)).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(Color(white: 0.32)).tracking(1)
        }
    }
}

struct GameButton: View {
    let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(color).clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Complete

struct GameCompleteView: View {
    @ObservedObject var game: GameEngine
    let onMenu: () -> Void
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🎉").font(.system(size: 48))
                Text("ALL 40 LEVELS DONE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 0.94, green: 0.72, blue: 0.18)).tracking(2)
                Text("You've mastered both layers and full sentences.")
                    .font(.system(size: 13)).foregroundColor(Color(white: 0.50)).multilineTextAlignment(.center)
                StatPill(label: "Best Streak", value: "\(game.bestStreak)").padding(.top, 6)
                GameButton(label: "Play Again", color: Color(red: 0.18, green: 0.60, blue: 0.38), action: onMenu)
            }
            .padding(28)
        }
    }
}

// MARK: - Root View

struct IOSContentView: View {
    @StateObject var game        = GameEngine()
    @StateObject var engine      = ChordEngine()
    @StateObject var calibration = CalibrationModel()

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()
            switch game.phase {
            case .intro:
                LevelSelectView(game: game,
                                onSelect:    { idx in game.startLevel(idx) },
                                onCalibrate: { game.phase = .calibrating })
            case .playing:
                PlayingView(game: game, engine: engine, calibration: calibration,
                            onMenu: { game.phase = .intro })
            case .levelComplete:
                LevelCompleteView(game: game,
                    onNext:  { game.startLevel(game.currentLevelIndex + 1) },
                    onRetry: { game.restart() },
                    onMenu:  { game.phase = .intro })
            case .gameComplete:
                GameCompleteView(game: game, onMenu: { game.phase = .intro })
            case .calibrating:
                CalibrationView(engine: engine, calibration: calibration,
                                onExit: { game.phase = .intro })
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            AppDelegate.lockLandscape()
            game.onResult = { correct, expected in
                calibration.learn(landings: engine.pendingLandings,
                                  expectedMask: expected, correct: correct)
            }
        }
        .onChange(of: game.phase) { _, phase in
            guard phase == .playing else { return }
            engine.onLetter    = { game.receiveLetter($0) }
            engine.onSpace     = { game.receiveSpace() }
            engine.onBackspace = { game.receiveBackspace() }
            // Auto-set layer based on level requirement
            engine.layer2Active = game.level.requireLayer2
        }
    }
}

// MARK: - Lock to landscape

class AppDelegate: NSObject, UIApplicationDelegate {
    static func lockLandscape() {
        if #available(iOS 16.0, *) {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }.first
            scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        }
    }
}
