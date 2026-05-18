/// Catalogue of scam patterns rendered on the `/learn` page.
///
/// The ids intentionally match the closed-set scam categories planned for
/// classifier metadata and history reporting:
/// extortion, imposter, phishing, romance, investment, employment, shopping,
/// and malware.
///
/// One object per scam type. Add a new entry to introduce a new card;
/// the page reflects the array order. All text is written at a roughly
/// sixth-grade reading level so it parallels the verdict-card copy the
/// inference pipeline produces: no jargon, short sentences.
export type ScamTopicId =
  | 'extortion'
  | 'imposter'
  | 'phishing'
  | 'romance'
  | 'investment'
  | 'employment'
  | 'shopping'
  | 'malware'

export interface ScamTopic {
  id: ScamTopicId
  emoji: string
  title: string
  tagline: string
  howItWorks: string
  redFlags: string[]
  whatToDo: string
}

export const scamTopics: ScamTopic[] = [
  {
    id: 'extortion',
    emoji: '🔒',
    title: 'Extortion',
    tagline: 'Threats meant to scare you into paying fast.',
    howItWorks:
      'A scammer claims they will hurt you, expose private photos, share a secret, or report you unless you pay. They may quote an old password from a data breach, show your contact list, or say they hacked your device. The goal is panic. They want you to act before you can think or ask for help.',
    redFlags: [
      'Threats to send photos, messages, or private details to family, school, or work.',
      'Payment demanded through crypto, gift cards, Cash App, wire transfer, or another hard-to-reverse method.',
      'A strict deadline like "pay in 2 hours" or "I send it now".',
      'An old password shown as "proof" of hacking.',
      'Pressure to keep the threat secret.',
    ],
    whatToDo:
      'Do not pay and do not keep negotiating. Save screenshots, block the account, and tell someone you trust. If a minor is involved, contact NCMEC at cybertipline.org. In the US, you can also report to the FBI at ic3.gov.',
  },
  {
    id: 'imposter',
    emoji: '🏛️',
    title: 'Imposter',
    tagline: 'Someone pretends to be a person or organization you trust.',
    howItWorks:
      'The scammer acts like a bank, police officer, government agency, delivery company, tech support worker, boss, family member, or friend. They use a familiar name to lower your guard, then demand money, codes, account access, or personal details. Caller ID, email names, and profile photos can all be faked.',
    redFlags: [
      'Claims from police, IRS, immigration, or a bank that require immediate payment.',
      'A "family member" or "boss" asking for gift cards or urgent transfers.',
      'Caller tells you to stay on the line or keep the conversation secret.',
      'Requests for login codes, one-time passcodes, or remote access to your device.',
      'Payment demanded by gift card, crypto, wire transfer, or payment app.',
    ],
    whatToDo:
      'Stop the conversation and contact the real person or organization using a number, app, or website you already trust. Do not use the link or phone number from the message.',
  },
  {
    id: 'phishing',
    emoji: '🎣',
    title: 'Phishing',
    tagline: 'Fake messages that try to steal your login or payment details.',
    howItWorks:
      'You get a text or email that looks like it came from your bank, Apple, Amazon, a delivery company, or another service. It says your account is locked, a package is held up, or a charge needs review. The link opens a fake page that captures whatever you type.',
    redFlags: [
      'A link that does not match the real company website.',
      'Urgency like "act within 24 hours" or "your account will be closed".',
      'Requests for your password, one-time code, full card number, or Social Security Number.',
      'Generic greetings like "Dear customer".',
      'Spelling, grammar, or layout mistakes that feel off.',
    ],
    whatToDo:
      'Do not tap the link. Open the company app or website yourself and check from there. If you already entered details, change that password and contact the bank or company directly.',
  },
  {
    id: 'romance',
    emoji: '💔',
    title: 'Romance',
    tagline: 'A warm relationship that slowly turns into a money request.',
    howItWorks:
      'Someone meets you on a dating app, social media, or messaging app. They are affectionate and attentive, but always have a reason they cannot meet in person. After trust builds, an emergency appears: medical bills, customs fees, legal trouble, travel costs, or a blocked account.',
    redFlags: [
      'Refuses to video call or says the camera is broken.',
      'Falls in love unusually fast.',
      'Profile photos look polished or show up elsewhere online.',
      'Any request for money, gift cards, crypto, or bank help.',
      'Stories that start small and grow into bigger emergencies.',
    ],
    whatToDo:
      'Do not send money or gifts to someone you have not met in person. Stop contact, save the messages, and report the account to the platform. Talk to someone you trust before responding again.',
  },
  {
    id: 'investment',
    emoji: '📈',
    title: 'Investment',
    tagline: 'Fake profit promises, often involving crypto or trading.',
    howItWorks:
      'A stranger, online friend, or new romantic contact tells you about a crypto, forex, stock, or trading platform that "always pays out". They may show fake profits in a polished app. When you try to withdraw, they ask for taxes, fees, or verification payments first.',
    redFlags: [
      'Claims of guaranteed, risk-free, or unusually high returns.',
      'A platform promoted through DMs, dating apps, Telegram, or WhatsApp.',
      'Pressure to invest before the chance closes.',
      'Asked to pay a fee to unlock your own money.',
      'A new friend quickly pivots from chatting to investment advice.',
    ],
    whatToDo:
      'Walk away. Real investing always has risk. Never send money to a platform from a DM, and never pay a fee to release your own funds.',
  },
  {
    id: 'employment',
    emoji: '💼',
    title: 'Employment',
    tagline: 'Fake jobs that ask you to pay before you earn.',
    howItWorks:
      'You get a message about easy work from home, product reviews, package handling, or online tasks. The job starts fast with little or no interview. Then you are asked to pay for training, equipment, software, background checks, or to unlock more tasks.',
    redFlags: [
      'Hired without a real interview.',
      'Asked to pay for training, equipment, or background checks upfront.',
      'Vague job details like "earn from your phone" or "no experience needed".',
      'Communicates only through text, Telegram, or WhatsApp.',
      'Asked to deposit checks, move money, or send crypto.',
    ],
    whatToDo:
      'Do not pay an employer to start a job. Real employers pay you. Look up the company, verify the recruiter, and use official company channels before sharing personal information.',
  },
  {
    id: 'shopping',
    emoji: '🛒',
    title: 'Shopping',
    tagline: 'Fake stores, fake sellers, fake buyers, and delivery tricks.',
    howItWorks:
      'A fake store offers a deal that looks too good to be true. A seller asks you to pay outside the app and disappears. A buyer overpays and asks for a refund. A delivery text claims your package needs a small fee or address update, but the link steals your card details.',
    redFlags: [
      'Prices far below normal.',
      'Seller insists on Zelle, Venmo Friends-and-Family, wire transfer, or crypto.',
      'Buyer overpays and asks you to refund the difference.',
      'Delivery notice with a link asking for card details.',
      'Store has no real address, reviews, return policy, or contact information.',
    ],
    whatToDo:
      'Use marketplace payments that offer protection. For delivery notices, open the carrier app or website yourself and search the tracking number. Never use the link from a random text.',
  },
  {
    id: 'malware',
    emoji: '🛡️',
    title: 'Malware',
    tagline: 'Links or files that try to install harmful software.',
    howItWorks:
      'A message, pop-up, email, or fake support alert tells you to download an app, install an update, open an attachment, or allow remote access. The software may steal passwords, read messages, watch activity, or let someone control your device.',
    redFlags: [
      'Unexpected attachments, QR codes, or download links.',
      'Pop-ups saying your device is infected and giving a phone number.',
      'Asked to install remote access tools like AnyDesk or TeamViewer.',
      'App install links outside the official App Store or Play Store.',
      'Instructions to disable security settings.',
    ],
    whatToDo:
      'Do not install the app or open the file. Close the page, delete the message, and update your device from settings or the official app store. If you already installed something suspicious, uninstall it and change important passwords from another device.',
  },
]
