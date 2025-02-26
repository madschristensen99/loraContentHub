# loraContentHub

# Background
I am developing a generative tik-tok-like short form video feed app on Livepeer. Demo available at:

https://claircent.com/dreamscroll/index.html

The app uses text to image software which can be easily and cheaply fine-tuned with loras to generate consistent characters and styles. 

https://huggingface.co/spaces/enzostvs/lora-studio

Creators making use of LoRA's cannot monetize their content without programmable IP. 
To solve this, I have created the contract loraContentHub that manages the process of registering LORA's, distributing royalites, and facilitating disputes. 

https://aeneid.storyscan.xyz/address/0x8ed734A9ab0074C20093ECC42E2610ED6139275C

# What It Does

Manages IP for LoRAs (AI models for video content) in a TikTok-like feed app on Story's testnet, handling registration, licensing, royalties, and disputes.

## Flow

1. **Register LoRA**:
   * Creator calls registerLoRA("ipfs://metadata").
   * Mints an ERC-721 NFT and registers it as IP.
2. **License LoRA**:
   * User calls createLicense(loRAId, "livepeer://video", 500) with 500 MERC20 stake.
   * Sets 5% royalty rate.
3. **Distribute Royalties**:
   * App calls distributeRoyalties(licenseId, 1000) with 1000 MERC20 revenue.
   * Pays 50 MERC20 to creator, refunds stake if no disputes.
4. **Raise Dispute**:
   * User calls raiseDispute(licenseId, "IP violation").
5. **Resolve Dispute**:
   * Owner calls resolveDispute(disputeId, true).
   * Disables license, sends stake to complainant.

## Story Contracts Used

* **IPAssetRegistry (0x77319B4031e6eF1250907aa00018B8B1c67a244b)**: Registers LoRAs as IP assets.
* **LicensingModule (0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f)**: Creates licenses with royalty terms.
* **RoyaltyModule (0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086)**: Records and distributes royalties.
* **DisputeModule (0x9b7A9c70AFF961C799110954fc06F3093aeb94C5)**: Manages IP disputes.
* **MERC20 (0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E)**: Token for staking and royalties.

## Problem Solved

* **Issue**: LoRAs (~$2 to make) can violate IP when trained on public images, and creators can't easily monetize or protect them.
* **Solution**: Registers LoRAs as IP, licenses them for video use, pays royalties in MERC20, and resolves disputes on-chain, making AI content creation legal and profitable.
