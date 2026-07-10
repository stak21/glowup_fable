//  Catalog.swift
//  Clearing

import Foundation

// MARK: - Catalog (products + full Week 3 schedule from the PDF)

enum Catalog {

    static let products: [String: Product] = [
        "cleanse": Product(name: "Cleanse", tag: "Fresh start",
            what: "A gentle cleanser to remove buildup, SPF, sweat and pollution.",
            why: "Actives only work on clean skin — cleansing first lets everything after it absorb properly.",
            order: "Always step one. Every serum and acid needs clean, completely dry skin."),
        "glowpads": Product(name: "Glow Up Pads", tag: "Sugar Baby · kojic + citric acid",
            what: "Pre-soaked pads with kojic and citric acid — a gentle AHA brightening swipe.",
            why: "Fades dark spots with light daily exfoliation. Gentle enough for face, bikini, armpits and chest.",
            order: "Right after cleansing — the thinnest, most watery step goes first so richer serums can layer over it."),
        "flavoc": Product(name: "Flavo-C Ultraglican", tag: "ISDIN · vitamin C",
            what: "A vitamin C antioxidant ampoule.",
            why: "Brightens, boosts collagen, firms, and adds UV defense that makes SPF work harder.",
            order: "First serum after pads — thin, water-light, and antioxidants perform best applied early."),
        "melaclear": Product(name: "Melaclear", tag: "ISDIN · tranexamic acid",
            what: "A tranexamic acid serum targeting pigmentation.",
            why: "Fades hyperpigmentation and stubborn dark spots — teams up with the vitamin C before it.",
            order: "After vitamin C, following the thin-to-thick serum rule."),
        "niacinamide": Product(name: "TJ Niacinamide + HA", tag: "Niacinamide + hyaluronic acid",
            what: "A niacinamide and hyaluronic acid serum.",
            why: "Minimises pores, controls oil, calms redness, hydrates. Daily hero for bikini, armpits and chest too.",
            order: "Last serum — thickest and most hydrating, it seals the brightening serums underneath."),
        "hyaleyes": Product(name: "Hyaluronic Eyes", tag: "ISDIN · eye contour",
            what: "A hydrating eye treatment. Pat gently with your ring finger.",
            why: "Hydrates the delicate eye area and reduces puffiness.",
            order: "Always AFTER all serums and actives, BEFORE moisturiser — the eye area gets its own layer here."),
        "spf": Product(name: "SPF", tag: "Every single morning",
            what: "Broad-spectrum sunscreen. Reapply every 2 hours outdoors.",
            why: "Your routine is full of actives that make skin sun-sensitive — SPF protects every result you're building.",
            order: "Final AM step, always. Sunscreen must sit on top of everything to form its protective film.",
            caution: "Never skip. Skipping SPF undoes the work of every other product."),
        "glycolic": Product(name: "Glycolic Acid", tag: "The Ordinary · AHA · face only",
            what: "A glycolic acid exfoliating toner, applied with a cotton pad.",
            why: "Smooths texture, brightens, fades dark spots, supports collagen.",
            order: "Straight after cleansing on glycolic nights — acids need direct skin contact. Wait the full 10 minutes.",
            caution: "FACE ONLY — never on armpits or chest. Avoid the eye area."),
        "azelaic": Product(name: "Azelaic Acid", tag: "The Ordinary",
            what: "An azelaic acid suspension.",
            why: "Fades dark spots, calms redness, fights acne. Safe on face, bikini, armpits and chest (alternate days on body).",
            order: "In the actives block, after any AHA and before hydration."),
        "salicylic": Product(name: "Salicylic Renewal", tag: "ISDIN · BHA · face only",
            what: "A salicylic acid treatment — twice weekly at week 3.",
            why: "Oil-soluble, so it unclogs pores from inside and fights acne, including the chest purge.",
            order: "The strongest step of the night goes last among actives, right before soothing hydration.",
            caution: "Wed + Sat only. Skip if skin feels sensitive. Face only — avoid mustache area on Wednesdays."),
        "retinal": Product(name: "Retinal Intense", tag: "ISDIN · face only",
            what: "A retinaldehyde treatment — a step stronger than retinol.",
            why: "Gold standard for anti-wrinkle, cell renewal and collagen. Softens elevens over time.",
            order: "After the niacinamide buffer, on completely dry skin, applied sparingly.",
            caution: "Tue + Fri only. Never with acids. Never steam on retinal nights. If irritated: Hyaluronic Concentrate only."),
        "hyalconc": Product(name: "Hyaluronic Concentrate", tag: "ISDIN · overnight hydration",
            what: "A deep hydration concentrate.",
            why: "Seals in moisture overnight and soothes after actives — your skin's recovery blanket.",
            order: "Final face step every evening — moisturiser locks everything underneath in place."),
        "niabuffer": Product(name: "Niacinamide (buffer)", tag: "Retinal nights only",
            what: "A niacinamide layer applied before retinal.",
            why: "A cushion that significantly reduces retinal irritation without weakening results.",
            order: "Immediately before Retinal Intense — it only works underneath."),
        "mask": Product(name: "Tata Harper Radiance Mask", tag: "Lactic acid + kaolin · 20 min",
            what: "A resurfacing clay mask — thick layer, massage until white, 20 min, rinse warm.",
            why: "Lactic acid gently exfoliates while kaolin deep-cleans pores opened by steam.",
            order: "Right after steaming while pores are open. Wednesdays: skip the mustache area."),
        "steam": Product(name: "Facial Steam", tag: "5 min · 20–30 cm away",
            what: "Warm steam on clean skin.",
            why: "Opens pores so the mask and actives after it work deeper.",
            order: "ALWAYS after cleansing, never on dirty skin. Never on retinal nights.",
            caution: "Wednesdays: shield the mustache area with a cool damp cloth after Nair."),
        "scrub": Product(name: "TJ Microdermabrasion Scrub", tag: "Pre-removal · body only",
            what: "A physical exfoliating scrub.",
            why: "Clears dead skin before hair removal so ingrowns can't form.",
            order: "Before Nair, in the warm shower."),
        "nair": Product(name: "Nair", tag: "Wednesday · right formula per area",
            what: "Depilatory cream — sensitive formula for armpits, bikini formula for bikini, FACIAL formula only for mustache.",
            why: "Far less trauma than shaving. Watch timing per packaging.",
            order: "After warm shower + scrub. Then cool rinse, pat dry, soothe with niacinamide.",
            caution: "NEVER body Nair on the face."),
        "minoxidil": Product(name: "Minoxidil", tag: "Scalp only · leave on",
            what: "A scalp treatment that stimulates hair follicles.",
            why: "Supports hair growth over 3–6 months of nightly use.",
            order: "The absolute last step of the night. Dry scalp, leave on, no rinse."),
        "dryskin": Product(name: "Clean, dry skin", tag: "After shower",
            what: "Pat completely dry before applying anything.",
            why: "Products absorb better and irritate less on fully dry skin.",
            order: "The foundation of every body-care step."),
        "tea": Product(name: "Spearmint tea", tag: "Minimum once daily · non-negotiable",
            what: "One cup — 85–90°C, steeped 5–7 min covered.",
            why: "Clinically shown to reduce androgens, which drive hormonal chin AND chest acne.",
            order: "Anytime today — pairing it with breakfast makes it automatic."),
        "water": Product(name: "Water 2.5–3 L", tag: "All day",
            what: "Your daily hydration minimum.",
            why: "Non-negotiable for skin repair, de-puffing, and making every serum's hydration count.",
            order: "Sip throughout the day."),
    ]

    static let amSteps: [RStep] = [
        RStep(key: "am0", productID: "cleanse", wait: 2),
        RStep(key: "am1", productID: "glowpads", wait: 2),
        RStep(key: "am2", productID: "flavoc", wait: 3),
        RStep(key: "am3", productID: "melaclear", wait: 3),
        RStep(key: "am4", productID: "niacinamide", wait: 2),
        RStep(key: "am5", productID: "hyaleyes", wait: 1),
        RStep(key: "am6", productID: "spf"),
    ]

    // JS-style weekday: 0=Sun ... 6=Sat
    static let pmByDay: [Int: DayPlan] = [
        1: DayPlan(focus: "Glycolic Glow", emoji: "✨", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2),
            RStep(key: "pm1", productID: "glycolic", wait: 10),
            RStep(key: "pm2", productID: "hyaleyes", wait: 1),
            RStep(key: "pm3", productID: "hyalconc"),
            RStep(key: "pm4", productID: "minoxidil"),
        ]),
        2: DayPlan(focus: "Retinal Renewal", emoji: "🌙", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Skin must be FULLY dry before retinal"),
            RStep(key: "pm1", productID: "glowpads", wait: 2),
            RStep(key: "pm2", productID: "niabuffer", wait: 3),
            RStep(key: "pm3", productID: "retinal", wait: 5),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
        3: DayPlan(focus: "Removal · Steam · Mask", emoji: "🧖‍♀️", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Always cleanse before steaming"),
            RStep(key: "pm1", productID: "steam", wait: 5, note: "Shield mustache area"),
            RStep(key: "pm2", productID: "mask", wait: 20, note: "Avoid mustache area"),
            RStep(key: "pm3", productID: "azelaic", wait: 5, note: "Avoid mustache area"),
            RStep(key: "pm4", productID: "salicylic", wait: 3, note: "Skip if skin feels sensitive"),
            RStep(key: "pm5", productID: "hyaleyes", wait: 1),
            RStep(key: "pm6", productID: "hyalconc", note: "Yes on mustache — soothing"),
            RStep(key: "pm7", productID: "minoxidil"),
        ]),
        4: DayPlan(focus: "Glycolic + Azelaic", emoji: "💫", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2),
            RStep(key: "pm1", productID: "glowpads", wait: 2, note: "Skip if sensitive — both are AHAs"),
            RStep(key: "pm2", productID: "glycolic", wait: 10),
            RStep(key: "pm3", productID: "azelaic", wait: 5),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
        5: DayPlan(focus: "Retinal Renewal", emoji: "🌙", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Skin must be FULLY dry before retinal"),
            RStep(key: "pm1", productID: "glowpads", wait: 2),
            RStep(key: "pm2", productID: "niabuffer", wait: 3),
            RStep(key: "pm3", productID: "retinal", wait: 5),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
        6: DayPlan(focus: "Azelaic + Salicylic", emoji: "🫧", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2),
            RStep(key: "pm1", productID: "azelaic", wait: 5),
            RStep(key: "pm2", productID: "salicylic", wait: 3, note: "If reactive, azelaic only tonight"),
            RStep(key: "pm3", productID: "hyaleyes", wait: 1),
            RStep(key: "pm4", productID: "hyalconc"),
            RStep(key: "pm5", productID: "minoxidil"),
        ]),
        0: DayPlan(focus: "Steam · Mask · Rest", emoji: "🛁", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Always cleanse before steaming"),
            RStep(key: "pm1", productID: "steam", wait: 5, note: "Weekly deep reset — 5–8 min"),
            RStep(key: "pm2", productID: "mask", wait: 20),
            RStep(key: "pm3", productID: "glowpads", wait: 2),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc", note: "Rest night — no strong acids after mask"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
    ]

    static let removalSteps: [RStep] = [
        RStep(key: "rem1", label: "Warm shower", note: "Softens hair follicles"),
        RStep(key: "rem2", productID: "scrub", label: "Scrub armpits · 30 sec"),
        RStep(key: "rem3", productID: "scrub", label: "Scrub bikini · 60 sec"),
        RStep(key: "rem4", productID: "nair", label: "Nair armpits", note: "Sensitive formula"),
        RStep(key: "rem5", productID: "nair", label: "Nair bikini", note: "Bikini formula"),
        RStep(key: "rem6", productID: "nair", label: "Nair mustache", note: "FACIAL formula only"),
        RStep(key: "rem7", label: "Cool rinse + pat dry", note: "Never rub"),
        RStep(key: "rem8", productID: "niacinamide", label: "Niacinamide to soothe"),
    ]

    static func bodySteps(area: String, includeAzelaic: Bool) -> [RStep] {
        var steps = [
            RStep(key: "\(area)-dry", productID: "dryskin"),
            RStep(key: "\(area)-nia", productID: "niacinamide"),
            RStep(key: "\(area)-pads", productID: "glowpads"),
        ]
        if includeAzelaic {
            steps.append(RStep(key: "\(area)-aze", productID: "azelaic", everyOtherDay: true))
        }
        return steps
    }

    static let habits: [RStep] = [
        RStep(key: "hb-tea", productID: "tea"),
        RStep(key: "hb-water", productID: "water"),
    ]

    static let weekInfo: [(day: Int, name: String, emoji: String, focus: String, key: String, note: String)] = [
        (1, "Monday", "✨", "Glycolic Glow", "Glycolic acid night — texture + brightness", "10-min wait after glycolic. Face only."),
        (2, "Tuesday", "🌙", "Retinal Renewal", "Niacinamide buffer + Retinal Intense", "Fully dry skin. No acids, no steam tonight."),
        (3, "Wednesday", "🧖‍♀️", "Removal · Steam · Mask", "Nair + steam + Tata Harper + azelaic + salicylic", "Big night! Protect the mustache area throughout."),
        (4, "Thursday", "💫", "Glycolic + Azelaic", "Double acid night", "Skip Glow Up Pads if skin feels sensitive."),
        (5, "Friday", "🌙", "Retinal Renewal", "Niacinamide buffer + Retinal Intense", "Same rules as Tuesday — dry skin, no heat."),
        (6, "Saturday", "🫧", "Azelaic + Salicylic", "Deep-clean acid duo", "Salicylic is twice weekly now (Wed + Sat)."),
        (0, "Sunday", "🛁", "Steam · Mask · Rest", "Steam + Tata Harper mask, then rest", "Recovery night — hydration only after the mask."),
    ]
}

