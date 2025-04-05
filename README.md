Overview

Mage Portal Assistant (MPA) is a WoW 1.12 addon designed to help mages efficiently manage portal requests from other players. It automates many aspects of the portal service process, including detecting requests, inviting players, and handling destination selection.
Features
Core Functionality

    Automatic Request Detection: Scans chat channels (whisper, party, say, yell, general) for portal requests

    Keyword Matching: Recognizes common portal request phrases ("port", "portal", "need a port", etc.)

    Destination Recognition: Identifies valid portal destinations from player messages

    Smart Invitation System: Automatically invites players who request portals (when party isn't full)

Portal Management

    Cooldown System: Prevents spam with player-specific cooldowns (default: 60 seconds)

    Party Integration: Tracks which requesters are in your party

    Destination Confirmation: Asks for clarification if destination isn't specified

    Invalid Destination Filtering: Ignores requests for unavailable locations (e.g., Ironforge, Stormwind)

User Interface

    Portal Request Window:

        Displays recent portal requests from chat

        Shows player name, message, and detected destination

        Includes "Whisper" and "Invite" buttons for each request

        "Clear All" button to reset the log

    Quick Access Buttons:

        All major water and food conjuring spells (organized by rank)

        "Oranges!" button for Ritual of Refreshment with fun emote

Trade Features

    Automatic Trade Acceptance: Accepts trades when using the /portal command

    Tip Recognition: Acknowledges tips with a thank-you message showing the amount

Commands

    /mpa on|off - Enable/disable the addon

    /mpa debug on|off - Toggle debug messages

    /mpa show|hide - Show/hide the portal request window

    /portal - Main portal command (use when ready to cast a portal)

Supported Portal Destinations

    Undercity (and common aliases: uc, under, etc.)

    Orgrimmar (and common aliases: org, og, etc.)

    Stonard (and common aliases: stonerd, stonart, etc.)

    Thunder Bluff (and common aliases: tb, tbluff, etc.)

Requirements

    World of Warcraft 1.12 client (Turtle Wow compatible)

    Mage character with portal spells

Installation

    Place the MagePortalAssistant.lua file in your Interface/AddOns folder

    Create a folder named MagePortalAssistant and place the file inside it

    Restart WoW or type /reload in game

Usage Tips

    The addon works automatically when enabled

    Use /portal when ready to cast a portal for a party member

    Check the request window to see recent portal requests

    Disable the addon with /mpa off when not providing portal services
