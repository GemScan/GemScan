/// Catalogue of scam patterns rendered on the `/learn` page.
///
/// One object per scam type. Add a new entry to introduce a new card;
/// the page reflects the array order. All text is written at a roughly
/// sixth-grade reading level so it parallels the verdict-card copy the
/// inference pipeline produces — no jargon, short sentences.
export interface ScamTopic {
  id: string
  emoji: string
  title: string
  tagline: string
  howItWorks: string
  redFlags: string[]
  whatToDo: string
}

export const scamTopics: ScamTopic[] = [
  {
    id: 'phishing',
    emoji: '🎣',
    title: 'Phishing',
    tagline: 'Fake messages that try to steal your login or payment details.',
    howItWorks:
      'You get a text or email that looks like it came from your bank, Apple, Amazon, or a delivery company. It tells you something urgent — your account is locked, a package is held up, a charge needs review — and pushes you to tap a link. The link opens a page that looks real but is actually a fake site that captures whatever you type.',
    redFlags: [
      'A link that doesn’t match the real company’s website (e.g. apple-secure-login.com instead of apple.com).',
      'Urgency: "act within 24 hours" or "your account will be closed".',
      'Requests for your password, one-time code, full card number, or Social Security Number.',
      'Generic greetings ("Dear customer") instead of your name.',
      'Spelling or grammar mistakes that a real company wouldn’t send.',
    ],
    whatToDo:
      'Don’t tap the link. Open the company’s app or website yourself and check from there. If the message is real, the same alert will be in your account. If you already entered details, change that password and contact the bank or company directly.',
  },
  {
    id: 'investment',
    emoji: '📈',
    title: 'Investment & crypto scams',
    tagline: '"Guaranteed" returns from a stranger or stranger-friend.',
    howItWorks:
      'Someone messages you out of the blue — sometimes after a long friendly chat — and tells you about a crypto, forex, or trading platform that "always pays out". They walk you through depositing money, show fake profits in a slick-looking app, and ask you to invest more. When you try to withdraw, you’re asked for a "tax", "fee", or "verification" first. The money is gone.',
    redFlags: [
      '"Guaranteed", "risk-free", or "double your money" claims.',
      'A platform you’ve never heard of, often promoted through Instagram, WhatsApp, or dating apps.',
      'Pressure to act fast before "the opportunity closes".',
      'Asked to pay a fee to unlock your withdrawal.',
      'A new friend who quickly pivots from chatting to investing tips.',
    ],
    whatToDo:
      'Walk away. Real investing has risk, no exceptions. Never send money to a platform you found through a DM, and never pay a fee to release your own funds — that’s always a scam.',
  },
  {
    id: 'tech-support',
    emoji: '🛠️',
    title: 'Tech-support scams',
    tagline: 'Fake "your device is infected" alerts asking for remote access.',
    howItWorks:
      'A pop-up on a website, a phone call, or an email claims your computer or phone is infected. They give you a number to call — or call you — and ask you to install a remote-access app. Once they’re in, they show fake errors, "find" stolen money, and ask you to send gift cards or transfer funds to "secure" your account.',
    redFlags: [
      'Pop-ups with a phone number and a loud warning sound.',
      'Anyone asking you to install AnyDesk, TeamViewer, or similar remote tools.',
      'Caller claims to be from Microsoft, Apple, or your ISP — those companies don’t call you about viruses.',
      'Asked to buy gift cards or transfer money to "protect" your account.',
    ],
    whatToDo:
      'Hang up. Close the browser. Apple and Microsoft will never call you about a virus. If you installed a remote tool, uninstall it, run a system update, and change your important passwords from a different device.',
  },
  {
    id: 'romance',
    emoji: '💔',
    title: 'Romance scams',
    tagline: 'A long, warm conversation that ends in a money request.',
    howItWorks:
      'You match on a dating app, or someone messages you on Instagram or WhatsApp. They’re affectionate, attentive, and always have a reason they can’t meet in person — they’re overseas, a soldier, an oil-rig engineer. After weeks or months, a sudden emergency comes up: medical bill, customs fee, lawyer, plane ticket. They need you to send money.',
    redFlags: [
      'Refuses to video call, or "the camera is broken".',
      'Falls in love unusually fast.',
      'Profile photos look too polished — reverse-image search often finds them online.',
      'Any request for money, gift cards, or crypto, no matter how urgent.',
      'Stories that escalate: small loan first, then bigger emergencies.',
    ],
    whatToDo:
      'Never send money or gifts to someone you haven’t met in person. If you have, stop all contact, save the messages, and report the account to the dating app or platform. Talk to a friend or family member — scammers rely on isolation.',
  },
  {
    id: 'sextortion',
    emoji: '🔒',
    title: 'Sextortion',
    tagline: 'Threats to share intimate photos unless you pay — always a crime, never your fault.',
    howItWorks:
      'There are two common versions. In one, an email claims "I hacked your webcam" and demands payment in crypto — sometimes quoting an old password of yours collected from a public data breach to seem real. In the other, especially common with teenagers and young men, you chat with someone who seems like a young woman online, things turn sexual fast, and after you send a photo or video they reveal they have your contact list and threaten to send it to your family, friends, school, or workplace unless you pay immediately.',
    redFlags: [
      'Demand to pay in Bitcoin, gift cards, or Cash App within hours.',
      'Threats to send images to your contacts, family, school, or employer.',
      'A new online "friend" who pushes the chat sexual unusually fast.',
      'An old password of yours in the email — it leaked in a data breach, not from your device.',
      'Pressure to keep it secret and act in panic — "if you tell anyone, I send it now".',
    ],
    whatToDo:
      'Stop replying. Do not pay — paying confirms you are scared and they will demand more. Block the account and take screenshots of everything. Tell a trusted adult, friend, or partner; you are not alone, and scammers rely on shame to keep you silent. Report to your local police, and in the US to the FBI at ic3.gov. If a minor is involved, contact NCMEC at cybertipline.org.',
  },
  {
    id: 'impersonation',
    emoji: '🏛️',
    title: 'Government & police impersonation',
    tagline: 'Fake IRS, immigration, or police calls demanding payment.',
    howItWorks:
      'You get a call or message claiming to be from the IRS, Social Security, immigration, or local police. They say you owe back taxes, missed jury duty, or are about to be arrested. They demand immediate payment — usually by gift card, wire transfer, or crypto — and threaten arrest, deportation, or a frozen bank account if you hesitate.',
    redFlags: [
      'Threats of arrest, deportation, or court action over the phone.',
      'Payment demanded by gift card, wire transfer, crypto, or app like Zelle.',
      'Caller ID shows a real agency’s number (numbers can be faked).',
      'Tells you to keep it secret or "stay on the line".',
    ],
    whatToDo:
      'Hang up. The IRS, police, and immigration never demand payment by gift card or crypto, and they don’t threaten arrest over the phone. If you’re worried it might be real, look up the agency’s number yourself and call them directly.',
  },
  {
    id: 'prize',
    emoji: '🎁',
    title: 'Prize & lottery scams',
    tagline: '"You won!" — for a contest you never entered.',
    howItWorks:
      'A text, email, or social-media DM tells you you’ve won a prize — a phone, a gift card, a lottery — usually from a brand you know. To claim it, you have to click a link, fill out a form, or pay a small "shipping" or "tax" fee. The prize never arrives, and your personal info or card number is stolen.',
    redFlags: [
      'You don’t remember entering the contest.',
      'Asked to pay any amount, no matter how small, to claim a prize.',
      'Link to a fake-looking landing page with a countdown timer.',
      'Asked for your card details for "verification".',
    ],
    whatToDo:
      'Delete the message. Legitimate prizes never require you to pay to receive them. If you’re curious, search the brand’s official website for the contest — you won’t find it.',
  },
  {
    id: 'job',
    emoji: '💼',
    title: 'Job & remote-work scams',
    tagline: 'Easy work-from-home jobs that ask you to pay first.',
    howItWorks:
      'You get a message about a job — often "review products online for $400/day" or "package handler" — that requires no interview and starts immediately. After signing up, you’re asked to pay for "training", "equipment", or "onboarding software", or to deposit money into an account to "unlock tasks". The job doesn’t exist; the upfront payment is the scam.',
    redFlags: [
      'Hired without an interview, sometimes within hours.',
      'Asked to pay for training, equipment, or background checks upfront.',
      'Payment promised in crypto or gift cards.',
      'Vague description: "earn from your phone", "no experience needed".',
      'Communicates only through Telegram, WhatsApp, or texts — never video.',
    ],
    whatToDo:
      'Never pay an employer to start a job — real employers pay you, not the other way around. Look up the company. If there’s no real website, no real address, and no real interview, it’s a scam.',
  },
  {
    id: 'marketplace',
    emoji: '🛒',
    title: 'Marketplace & shipping scams',
    tagline: 'Fake buyers, fake sellers, and fake delivery notices.',
    howItWorks:
      'Selling on Facebook Marketplace or Craigslist: a "buyer" sends a payment "by mistake" and asks for a refund. Buying: a "seller" lists an item way under market price, asks you to pay through a non-standard method, then disappears. As a delivery scam, you get a text from "USPS" or "FedEx" saying your package can’t be delivered until you update your address or pay a small fee — the link captures your card.',
    redFlags: [
      'Buyer who overpays and asks for a refund.',
      'Seller who insists on Zelle, Venmo Friends-and-Family, wire transfer, or crypto.',
      'Item priced suspiciously low.',
      '"Failed delivery" text with a link to enter card details for a small fee.',
      'Shipping update from a carrier you didn’t use.',
    ],
    whatToDo:
      'Stick to in-app payments that offer buyer/seller protection. For delivery notices, open the carrier’s app or website yourself and search for the tracking number — never use the link from the text.',
  },
]
