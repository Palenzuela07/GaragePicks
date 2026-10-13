# GaragePicks

An iOS app that helps resellers figure out what an item is worth before they buy it. Snap photos at a garage sale, thrift store, or flea market, and GaragePicks identifies the items with AI and pulls recent eBay sold prices so you can spot the deals.

## Features

- **AI item identification** – Upload up to 6 photos at once; GPT-4o (vision) analyzes them together and returns a clean list of eBay-searchable product names.
- **Real sold-price data** – Each identified item is priced using the eBay Browse API, showing low / mean / high prices from sold listings.
- **Value highlighting** – Items are color-coded by average sale price so high-value finds stand out at a glance.
- **Sort by price or name** – Quickly surface the most valuable items in a haul.
- **In-app eBay browsing** – Tap any item to view eBay's completed & sold listings in an in-app web view, Safari, or the eBay app.
- **User accounts** – Sign up, log in, and password reset via Firebase Authentication, with Face ID / Touch ID sign-in.
- **Dark mode support**

## Tech Stack

| Area | Technology |
|------|------------|
| Language / UI | Swift, SwiftUI |
| AI | OpenAI GPT-4o Vision API |
| Pricing data | eBay Browse API (OAuth 2.0 client credentials) |
| Auth | Firebase Authentication, LocalAuthentication (biometrics), Keychain |
| HTML parsing | SwiftSoup |
| Web content | WebKit (WKWebView) |
| Payments | Stripe (in progress) |

## How It Works

1. User selects or takes up to 6 photos.
2. Images are compressed, base64-encoded, and sent to GPT-4o with a prompt tuned for identifying resellable products.
3. The response is parsed into individual product names.
4. Each product is searched against the eBay Browse API (US, sold items, sorted by most recent).
5. Results are filtered by title relevance and recency (last 90 days), then summarized into price statistics.

## Getting Started

### Requirements
- Xcode 16+
- iOS 18.1+
- API credentials for OpenAI, eBay Developer Program, and a Firebase project

### Setup
1. Clone the repo:
   ```bash
   git clone https://github.com/Palenzuela07/GaragePicks.git
