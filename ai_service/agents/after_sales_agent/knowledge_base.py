"""
RAG Knowledge Base for PCForge After-Sales Service Agent (Member 05)
===================================================================
Contains comprehensive troubleshooting guides, safety protocols, and warranty
inspection procedures for PC hardware components and desktop systems.
Retrieved dynamically during conversational diagnosis.
"""

from typing import Any, Dict, List, Optional
import re


TROUBLESHOOTING_KNOWLEDGE_BASE: List[Dict[str, Any]] = [
    {
        "category": "Emergency Safety Hazard",
        "keywords": [
            "burn", "burning", "burnt", "smoke", "smoking", "spark", "sparks", "fire",
            "liquid", "spill", "water", "coffee", "wet", "shock", "zap", "electrical",
            "bulge", "capacitor", "exploded", "melt", "melted", "damaged"
        ],
        "is_safety_hazard": True,
        "hazard_instructions": (
            "CRITICAL ELECTRICAL & PHYSICAL SAFETY WARNING: "
            "Immediately turn off the power strip or unplug the PC power cable from the wall outlet. "
            "Do NOT attempt to power on the PC again. Do NOT open the power supply unit. "
            "Immediate in-person technician inspection at the PCForge Service Center is required."
        ),
        "recommended_action": "IMMEDIATE_ESCALATION"
    },
    {
        "category": "Power / Boot Failure",
        "keywords": ["not turning on", "won't turn on", "no power", "dead", "power button", "does not turn on", "pc won't start", "wont start", "no lights"],
        "is_safety_hazard": False,
        "description": "PC shows zero signs of power, no fan spin, and no front LED lights when pressing power button.",
        "steps": [
            {
                "step_number": 1,
                "title": "Check Wall Outlet & Power Cable Firmness",
                "instruction": "Let's start with a simple check. Please make sure the main power cable is firmly pushed into the back of your PC power supply and securely plugged into a working wall outlet (avoid loose extension boards if possible). Then try pressing the power button.",
                "verification_question": "Does any light turn on or fan twitch when you press the power button?"
            },
            {
                "step_number": 2,
                "title": "Check Power Supply I/O Rocker Switch",
                "instruction": "Please look at the back of your PC where the power cable plugs in. There is a small rocker switch with 'I' and 'O'. Please ensure the switch is flipped to the 'I' (ON) position, then press the front power button again.",
                "verification_question": "Was the switch on 'O', and does the PC turn on now when set to 'I'?"
            },
            {
                "step_number": 3,
                "title": "Test with an Alternate Wall Socket",
                "instruction": "Sometimes surge protectors or specific wall outlets trip. Please plug the power cable directly into a different wall socket in another room without using an extension cord, and try turning it on.",
                "verification_question": "Does the PC receive power from the different outlet?"
            },
            {
                "step_number": 4,
                "title": "Power Drain & Residual Charge Discharge",
                "instruction": "Let's perform a safe power drain: Unplug the power cable from the back of the PC. While unplugged, press and hold down the front power button for 30 seconds to drain residual electricity. Then plug the power cable back in and try turning it on.",
                "verification_question": "Did draining the power restore power to the system?"
            },
            {
                "step_number": 5,
                "title": "Inspect External Power Strip & Cable Condition",
                "instruction": "Please inspect the external power cable for any visible tears or kinks, and try swapping with a standard 3-prong desktop power cable (like one from a monitor) if you have one available.",
                "verification_question": "Did the alternate cable restore power to the PC?"
            }
        ]
    },
    {
        "category": "Display / Black Screen",
        "keywords": ["black screen", "no display", "no signal", "monitor black", "screen is black", "display not working", "blank screen", "no picture"],
        "is_safety_hazard": False,
        "description": "PC powers on (fans spin, lights turn on) but the monitor reports 'No Signal' or remains black.",
        "steps": [
            {
                "step_number": 1,
                "title": "Check Monitor Cable Port (GPU vs Motherboard)",
                "instruction": "Let's check the cable at the back of your PC. If your PC has a dedicated graphics card (installed horizontally lower down), make sure your HDMI or DisplayPort cable is plugged into the graphics card port, NOT the motherboard ports at the top.",
                "verification_question": "Was the display cable plugged into the graphics card or motherboard?"
            },
            {
                "step_number": 2,
                "title": "Verify Monitor Input Source & Power",
                "instruction": "Please check your monitor's power light to ensure it is turned on. Use the monitor's physical buttons or joystick to select the correct Input Source (e.g. HDMI 1 or DisplayPort 1).",
                "verification_question": "Does selecting the manual input source display the screen?"
            },
            {
                "step_number": 3,
                "title": "Reseat Display Cable on Both Ends",
                "instruction": "Please unplug the HDMI/DisplayPort cable completely from both your monitor and your PC, blow gently to clear any dust, and plug it back in firmly until it clicks into place.",
                "verification_question": "Did reconnecting the cable bring back the display signal?"
            },
            {
                "step_number": 4,
                "title": "Test with an Alternate Display Cable or Port",
                "instruction": "If your graphics card or monitor has an alternate port (such as a second HDMI or DisplayPort), please try plugging into the other port or test with an alternate HDMI cable.",
                "verification_question": "Does an alternate port or cable show a display signal?"
            },
            {
                "step_number": 5,
                "title": "Check Keyboard Lock Lights (CAPS/NUM lock test)",
                "instruction": "When the PC is on, tap the 'Caps Lock' or 'Num Lock' key on your keyboard. Check if the little light on the keyboard turns on and off. If it does, Windows is booting in the background, confirming a display/monitor connection issue rather than a motherboard failure.",
                "verification_question": "Do the keyboard indicator lights respond to Caps Lock?"
            }
        ]
    },
    {
        "category": "Shutdowns / Restarts",
        "keywords": ["restart", "restarting", "keeps restarting", "turns off", "suddenly turns off", "random shutdown", "shutting down", "crashes", "crashing", "loop"],
        "is_safety_hazard": False,
        "description": "PC unexpectedly powers down or reboots while in use or during gaming.",
        "steps": [
            {
                "step_number": 1,
                "title": "Check Airflow & Dust Clearance around Fans",
                "instruction": "Unexpected shutdowns are often triggered by built-in thermal safety mechanisms. Please make sure your PC tower is positioned in an open area with at least 10 cm of clearance on all sides, and not enclosed inside a tight cabinet or placed on thick carpet.",
                "verification_question": "Is the PC in an open space, and are all fan vents clear?"
            },
            {
                "step_number": 2,
                "title": "Listen for Fan Operation During Boot",
                "instruction": "When you turn on the PC, listen closely and look through the side panel if visible: do the case fans and CPU/GPU fans spin up normally without grinding?",
                "verification_question": "Are the fans spinning normally or are any stopped?"
            },
            {
                "step_number": 3,
                "title": "Disconnect Non-Essential External USB Devices",
                "instruction": "Faulty external USB devices (damaged flash drives, USB hubs, or external controllers) can cause short-circuit resets. Please unplug all external USB devices except for your basic keyboard and mouse, and test the PC.",
                "verification_question": "Does the PC stay on without unexpected restarts with external USBs unplugged?"
            },
            {
                "step_number": 4,
                "title": "Safe Mode Boot or Idle Observation",
                "instruction": "Does the shutdown occur immediately when starting Windows, or only when playing intensive games / heavy software? If it only happens during gaming, it indicates heavy load thermals or power supply tripping under load.",
                "verification_question": "Does it crash at desktop idle or only under heavy gaming/apps?"
            },
            {
                "step_number": 5,
                "title": "Check Wall Power Stability",
                "instruction": "Ensure the PC is not plugged into a multi-plug sharing heavy appliances (air conditioner, refrigerator, laser printer), which can cause voltage dips that trigger PSU safety shutoffs.",
                "verification_question": "Is the PC plugged into a dedicated, stable outlet?"
            }
        ]
    },
    {
        "category": "Performance / Slowness",
        "keywords": ["slow", "very slow", "sluggish", "lagging", "freezing", "stuttering", "unresponsive", "hangs", "hanging"],
        "is_safety_hazard": False,
        "description": "PC takes a very long time to open applications, desktop stutters, or Windows feels sluggish.",
        "steps": [
            {
                "step_number": 1,
                "title": "Clean Reboot via Windows Restart",
                "instruction": "Let's perform a fresh system restart. Please click Start -> Power -> 'Restart' (not Shut Down, because Windows Fast Startup can retain cached memory states during Shut Down).",
                "verification_question": "Did a clean restart improve the system responsiveness?"
            },
            {
                "step_number": 2,
                "title": "Check Available Storage Space on Main Drive (C:)",
                "instruction": "When the main system drive (C:) is nearly full, Windows struggles to manage virtual memory swap files. Please open 'This PC' and check if your Local Disk (C:) has at least 25 GB of free space.",
                "verification_question": "Does your C: drive have plenty of free space, or is the bar red?"
            },
            {
                "step_number": 3,
                "title": "Inspect Task Manager for High Background Usage",
                "instruction": "Press Ctrl + Shift + Esc on your keyboard to open Task Manager. Look at the 'Processes' tab at the top. Is CPU, Memory, or Disk running at 95% to 100%?",
                "verification_question": "Which column (CPU, Memory, or Disk) shows high usage, if any?"
            },
            {
                "step_number": 4,
                "title": "Disable Unnecessary Startup Applications",
                "instruction": "In Task Manager, click on the 'Startup apps' tab. Check if several unnecessary programs (like game launchers or background updaters) are enabled on startup, and right-click to Disable non-essential ones.",
                "verification_question": "Did disabling background startup apps help the PC speed?"
            },
            {
                "step_number": 5,
                "title": "Check for Pending Windows Updates",
                "instruction": "Sometimes Windows Update runs intensive indexing in the background. Open Windows Settings -> Update & Security and check if updates are downloading or waiting to install.",
                "verification_question": "Are there pending updates installing in the background?"
            }
        ]
    },
    {
        "category": "Audio / Strange Noise",
        "keywords": ["noise", "strange noise", "rattling", "buzzing", "whining", "loud", "grinding", "clicking", "clicking sound"],
        "is_safety_hazard": False,
        "description": "Unusual acoustic noises such as buzzing, clicking, rattling, or high-pitched coil whine.",
        "steps": [
            {
                "step_number": 1,
                "title": "Locate Noise Source (Fans vs Internal)",
                "instruction": "Let's identify where the sound is coming from. With the PC running, listen carefully near the front, top, and rear fans. Does the noise sound like a rapid clicking or light rattling against a plastic blade?",
                "verification_question": "Does the noise sound like it is coming from a fan location?"
            },
            {
                "step_number": 2,
                "title": "Check for Loose External Cables Near Fans",
                "instruction": "Please inspect the outside and back of your PC tower: make sure no loose cables (like an audio jack, USB cable, or power wire) are resting against the rear or top exhaust fan grills.",
                "verification_question": "Are any external cables touching the fan grills?"
            },
            {
                "step_number": 3,
                "title": "Observe Vibration on Desk Surface",
                "instruction": "Gently place your hand flat on the top of the PC case. If the case is vibrating against a hollow wooden desk, the vibration can amplify into a loud buzzing sound. Placing a mousepad or mat beneath the feet can dampen this.",
                "verification_question": "Does lightly pressing the top of the case silence the buzzing?"
            },
            {
                "step_number": 4,
                "title": "Differentiate Coil Whine vs Fan Bearing",
                "instruction": "Does the noise sound like a high-pitched electrical buzzing that only happens when a game is running with high frame rates, or does it happen constantly even on the desktop?",
                "verification_question": "Does the buzzing only occur during games or constantly at desktop?"
            },
            {
                "step_number": 5,
                "title": "Verify Side Panel Thumbscrew Tightness",
                "instruction": "Check the thumbscrews on the back corners holding the side glass panel. If they are slightly loose, the glass or metal panel can vibrate against the chassis frame.",
                "verification_question": "Did gently tightening the side panel thumbscrews stop the rattle?"
            }
        ]
    },
    {
        "category": "GPU / Graphics Component Fault",
        "keywords": ["gpu", "graphics card", "rtx", "radeon", "artifacting", "lines on screen", "game crash", "gpu not working", "driver timeout", "glitch"],
        "is_safety_hazard": False,
        "description": "Visual artifacts, screen glitches, green lines, driver crashes, or GPU fans running at 100%.",
        "steps": [
            {
                "step_number": 1,
                "title": "Check GPU PCIe Power Connectors Firmness",
                "instruction": "Look through your side panel at the graphics card: are the power cables (8-pin or 16-pin) plugged firmly into the card with no gaps visible at the connector latch?",
                "verification_question": "Do the power cables appear fully inserted and latched into the GPU?"
            },
            {
                "step_number": 2,
                "title": "Restart GPU Graphics Driver Shortcut",
                "instruction": "If the screen glitches or freezes, press the Windows GPU restart shortcut: hold down Windows Key + Ctrl + Shift + B simultaneously. Your screen will flicker once and beep, reloading the graphics driver.",
                "verification_question": "Did the shortcut beep and refresh your graphics output?"
            },
            {
                "step_number": 3,
                "title": "Test Resolution & Refresh Rate Adjustment",
                "instruction": "In Windows Settings -> Display -> Advanced Display, try temporarily reducing the monitor refresh rate (e.g. from 165Hz to 60Hz or 120Hz) or test with standard 1080p to see if signal stability improves.",
                "verification_question": "Does setting standard 60Hz resolve the display glitching?"
            },
            {
                "step_number": 4,
                "title": "Clean Graphics Driver Installation (GeForce Experience / AMD Adrenalin)",
                "instruction": "Open NVIDIA GeForce Experience or AMD Software and check if an update is available. If possible, select 'Custom Installation' -> 'Perform clean installation' to reset corrupted shader caches.",
                "verification_question": "Did updating or reinstalling the graphics driver fix the crashing?"
            },
            {
                "step_number": 5,
                "title": "Inspect for Thermal Throttling",
                "instruction": "When running a game, do the graphics card fans spin, or does the screen turn black after 5-10 minutes while audio continues playing in the background?",
                "verification_question": "Does the crash happen after 5-10 minutes of gameplay while audio still plays?"
            }
        ]
    }
]


def search_troubleshooting_knowledge(query: str) -> Dict[str, Any]:
    """Retrieves relevant troubleshooting knowledge and guidance based on non-technical customer description."""
    q_clean = (query or "").lower().strip()

    # 1. Immediate Safety Check (Highest Priority)
    hazard_guide = TROUBLESHOOTING_KNOWLEDGE_BASE[0]
    for kw in hazard_guide["keywords"]:
        if re.search(r"\b" + re.escape(kw) + r"\b", q_clean):
            return {
                "matched_category": hazard_guide["category"],
                "is_safety_hazard": True,
                "hazard_instructions": hazard_guide["hazard_instructions"],
                "recommended_action": "IMMEDIATE_ESCALATION",
                "guidance": (
                    "Safety Alert: Customer reported potential hazard (" + kw + "). "
                    "Do NOT instruct customer to troubleshoot. Advise immediate power disconnection and create a Service Request."
                )
            }

    # 2. Match Category by Keywords
    best_match = None
    max_score = 0

    for guide in TROUBLESHOOTING_KNOWLEDGE_BASE[1:]:
        score = 0
        for kw in guide["keywords"]:
            if kw in q_clean:
                score += len(kw)  # longer match weights higher
        if score > max_score:
            max_score = score
            best_match = guide

    # Default fallback to General Hardware if no specific keyword matched
    if not best_match:
        best_match = TROUBLESHOOTING_KNOWLEDGE_BASE[1]  # Power / Boot as safe baseline

    return {
        "matched_category": best_match["category"],
        "is_safety_hazard": False,
        "description": best_match.get("description", ""),
        "steps_available": best_match.get("steps", []),
        "total_steps": len(best_match.get("steps", [])),
        "guidance": (
            f"Diagnosing under category '{best_match['category']}'. "
            f"Select the next unattempted step in order (1 to 5). Never repeat already attempted steps. "
            f"If unresolved after 5 steps, transition to Service Request."
        )
    }
