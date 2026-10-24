// The games' and the demos' manuals, for the site's Manual window (site.js
// showManual) - and a short line of each one's keys for the DOS window's
// frame (drawMachineLine). The words are the old pages' (owlfly*.html,
// play.html - which now send their visitors here, ?play=), moved as they
// were, with what is no longer true on this site taken out: the phone's
// stick and buttons (not here), "click the screen" and "keep this tab
// visible" (the site does both), "the full manual lives on another page"
// (it is here). And one section is new: how the sky works on this site.
//
// A manual is a list of blocks: { h } a heading, { p } a paragraph, { k:
// [[key, what], ...] } a table of keys. manualLines() lays them out to a
// window's width.

/** How the site's sky works, for the networked games (Sky.cs, WAR.INC). */
const ON_THIS_SITE = [
  { h: 'ON THIS SITE' },
  { p: 'Everyone who plays this game on the site flies one sky, hosted by the site\'s server: one map for all. Every half hour, on the clock (:00 and :30), the server opens a new map; the DOS window\'s title counts down the last minute, and then the game starts again in the new sky - everyone together, so nobody is left alone in the old one. A round is half an hour: fly in, shoot, leave. To fly alone, switch the network off - the DOS window\'s Machine > Settings > Network, the IPX network card, or dosbox ipx=no in the terminal - and the game runs its own war and no new map comes. dosbox ipx=yes brings you back.' },
  { p: 'The war is shared as well. The bots and the Shilkas are run by the first pilot in the sky and sent to everyone else; your guns hit them at once on your own screen and tell that pilot. When the first pilot leaves, the next one carries the war on from where it stood. Alone, or without the server, you run your own.' },
  { p: 'And every human who joins is the enemy. The first pilot deals the people in the sky into two even sides, each newcomer to the smaller one; when people leave and the sides go uneven, the last to join changes sides - at the next life, never in the air. The second side takes off from the northern fields, facing south, and the colours, the radar and the score follow your side.' },
  { p: 'LAN > Live map shows the sky from above: every jet, the bots, the Shilkas, and a shared screen to click and watch.' },
];

/** OWL FLY II's keys - OWL FLY III's too, key for key. */
const OWL2_KEYS = [
  { h: 'CONTROLS - all of them' },
  { k: [
    ['<- / ->', 'bank left / right. Roll goes through 360 degrees - loops and barrel rolls work (numpad 4/6)'],
    ['^ / v', 'push the nose down / pull it up, flight-sim yoke (numpad 8/2)'],
    ['1 / 3', 'rudder pedals - a flat turn without dropping a wing (numpad 7/9). This is how you line up on a runway or hold a gun run'],
    ['W / S', 'throttle up / down - idle to the stop in about a second. The numpad + / - and the main-row = ramp the same way'],
    ['Shift', 'with any throttle key, slams the lever - Shift+W to full military, Shift+S to idle. The main-row + is Shift+=, so + always slams and = always ramps'],
    ['A', 'afterburner - four times dry thrust, and eight times the fuel. It is what takes you off the runway and what wins a climb; leave it lit and you have about eighty seconds of it'],
    ['F / L / B', 'flaps / landing gear / airbrake. Nothing is interlocked and nothing is refused: put the gear down at six hundred knots if you like, and wear the drag'],
    ['hands off', 'the aeroplane rights itself and trims to level'],
    ['Enter', 'lock whatever is inside the aiming ring. Enter on empty sky drops the lock'],
    ['Space', '(hold) cannon. Real tracer with a real time of flight - you lead the target, the game does not do it for you'],
    ['Backspace', 'missile. Homes on the lock; without one it flies straight ahead and hits whatever is unlucky'],
    ['Z / X', 'radar zoom in / out. In the F4 camera the same two keys pull the view in and out'],
    ['M', 'centre screen: MAP -> SIT -> TGT'],
    ['G / U', 'ground net / air net - your lock is broadcast to your own flak and your own aeroplanes'],
    ['I', 'IFF transponder. Up, your flak leaves you alone. Down, it does not'],
    ['R', 'radar emissions on / off'],
    ['T O P J Y', 'TACAN, master mode, autopilot, ECM, jammer - the plates toggle; only the master mode lamp does anything yet'],
    ['F2', 'cockpit on / off (the HUD tapes stay)'],
    ['F3', 'chase view - your own jet from behind, banking for real. The only place you can see your own landing gear'],
    ['F4', 'orbit the locked target. The arrows steer the camera, Z / X the distance'],
    ['F5', 'arm the missile camera: the next launch is ridden all the way to impact'],
    ['F6 / F7', 'turn your head ninety degrees left / right, and you are looking at a painted side console with the world going past it. The same key again faces forward'],
    ['Ctrl+arrows', 'the same head turn on the arrows - hold Ctrl and look. Let Ctrl go and the arrows fly the aeroplane again'],
    ['N', 'day / night. The stars are a real celestial sphere - they turn with your heading, pitch and bank'],
    ['V', 'sound, cycling: everything -> effects only -> silence -> everything'],
    ['Ctrl+D', 'the diagnostic marks, off by default - for catching a freeze; nothing a flight needs'],
    ['Space', 'after GAME OVER: take a fresh jet'],
    ['Alt+Q', 'quit to DOS'],
  ] },
];

/** How a sortie goes in OWL FLY II and III: off the ground, the fight, the panel. */
const OWL2_FLYING = [
  { h: 'GETTING OFF THE GROUND' },
  { p: 'A sortie starts stopped on your own concrete - fuelled, towed out, made ready, flaps set, gear down, engine running and standing on the brakes; the aeroplane says so on the glass until it is no longer true. So does every life after a death. The first thing any flight contains is a takeoff, and it goes like this:' },
  { p: 'B to release the brakes - W (or Shift+W to slam the lever to the stop) - A for the burner - hold the stick back, and she rotates and flies. Steer with the arrows: the nose wheel bites harder the faster you are rolling, which is why the first attempt wanders. Clean up with L and F once you are climbing.' },
  { p: 'You will not get airborne dry. On full dry thrust with the gear and flaps out this jet settles at a speed below the one it needs to fly; the nose comes up, the speed stops climbing, and nothing happens. That is not a fault, it is the aeroplane telling you what it wants. Light the burner.' },
  { h: 'HOW TO FIGHT' },
  { p: 'Find him. The left screen is a heading-up radar: your own nose points up the glass, so everything on it is measured against where you are looking. Green is ours, red is theirs, and a white pip with a letter is a real pilot. Each blip is an aeroplane symbol swung to its own heading, with a tick above or below for higher or lower than you. Z and X change the range.' },
  { p: 'Look for him. A fight does not stay in front of you. F6 and F7 turn your head ninety degrees left and right - or hold Ctrl and use the arrows - and you are looking out of the side of a real cockpit, past a painted console, with the world going by. Same key again to face forward.' },
  { p: 'Point at him. The aiming ring on the HUD is the lock gate. Fly until he is inside it and press Enter. The ring becomes a lock pointer that keeps showing where he is when he leaves the glass, the TGT page fills in with his callsign, type, range and altitude, and the missile now has somewhere to go. Enter on empty sky lets him go.' },
  { p: 'Kill him. The cannon is 250 rounds of real tracer with a real time of flight: aim where he will be, not where he is, and fire in short bursts. The missile is smarter and there are only four - it wants a lock, and it wants him in front of you and not on the deck. A jet takes 5 hits; so do you, and the fifth replays your last five seconds before GAME OVER.' },
  { p: 'Do not get killed. The LOCK lamp and the missile warning on the overhead strip mean somebody has done to you what you just did to him. There is no chaff and no flare yet, so the answer is the aeroplane: unload, get the nose down, and put a hill between you and the thing that is guiding.' },
  { p: 'The ground has opinions. Two radar stations and twenty flak vehicles hold the line, and the flak leads its shots. With the G net up they shoot at what you have locked instead of what is nearest their barrel - one pilot\'s eyes become the battery\'s. With the I transponder down they shoot at you, and they are right to.' },
  { p: 'Being invisible costs you your eyes. R stops your radar transmitting. You stop painting yourself on other people\'s scopes, and your own screen goes to snow - a radar that is not transmitting has nothing to receive. Knocking down the enemy\'s ground station does the same to him.' },
  { h: 'THE COCKPIT' },
  { k: [
    ['caution strip', 'MC MW AA DM FU FR GD - amber sits, red flashes'],
    ['radar', 'the left screen, heading-up: your nose is up. Z / X zoom, R stops transmitting'],
    ['centre MFD', 'M pages it: MAP the north-up island, SIT the close-in scope, TGT the locked target'],
    ['stores', 'GUN rounds, MSL rails, DAM damage, FUEL minutes - nothing here reloads'],
    ['warnings', 'STALL, FUEL, TERR, FIRE - and LOCK: you are had'],
    ['tapes', 'SPD speed, ALT altitude, NAV heading, HDG climb rate'],
  ] },
  { h: 'THE SWITCH PANEL' },
  { p: 'Twelve plates along the bottom: the up-front panel on the left, the self-protection suite on the right. The rule they are built on: a switch changes what OTHERS do, never what you are allowed to do.' },
  { k: [
    ['GND (G)', 'your lock goes out to your own flak batteries and they shoot at what you designate. The range gate still applies - a radio carries a designation, not a longer barrel'],
    ['AIR (U)', 'the same for your own aeroplanes: your side attacks what you are locked onto instead of whoever they noticed first'],
    ['IFF (I)', 'the transponder, and the most dangerous switch on the panel. Up, your own flak leaves you alone. Down, it does not'],
    ['T-R (R)', 'emissions: unseen, and blind'],
    ['A-A/A-G (O)', 'master mode, one lamp or the other. The weapons do not care which way it is set yet'],
    ['the rest', 'TACAN, autopilot, countermeasures, jammer, chaff, flares: the plates toggle and that is all they do so far. An unlit plate is an honest way to say "not yet"'],
  ] },
  { h: 'THE AERODROMES' },
  { p: 'Four strips, two a side, standing back from the line with a radar mast on the front pair. Grey slab, dashed centreline, a threshold bar at each end; three hangars and a control tower stand on the apron - scenery: you can fly straight through the tower.' },
  { p: 'Landing is the work in progress: flaps down or it is not a landing, gear too, and a belly arrival refuels nobody. Your own field gives you fuel and rails back. Theirs gives you nothing - but you can put down on it and work the place over, which is a different kind of sortie altogether.' },
  { h: 'THE WAR' },
  { p: 'Buildings fall and stay ruins. Wreckage chains - a jet that comes apart over a city takes part of the city with it. Ramming works. Once.' },
];

/** A demo of A:\EXAMPLES: its words from play.html, and where its source is. */
function demo(title, keys, what, why, asm) {
  return {
    title, keys, example: true,
    blocks: [
      { h: 'KEYS' }, { p: keys },
      { h: 'WHAT THIS IS' }, { p: what },
      { h: 'WHY IT IS WORTH A LOOK' }, { p: why },
      { h: 'ITS SOURCE' },
      { p: `A:\\EXAMPLES\\${asm}. The site builds it from that source every time it starts it, on the DOS PC, with FASM. Sources > Examples opens it in the editor; change it, and F9 there builds it and runs it again.` },
    ],
  };
}

export const MANUALS = {
  owlfly2: {
    title: 'OWL FLY II',
    keys: 'B brakes, W/S throttle, A burner, arrows fly, Enter lock, Space gun, Bksp missile, Alt-Q quit',
    blocks: [
      { h: 'WHAT THIS IS' },
      { p: 'A multiplayer combat flight sim in 8086 assembly. Two squadrons fight an attrition war over a procedural island minted from a two-byte seed - which is why joining a sky is instant: the advertisement carries the seed, your machine builds the same island, the same city and the same clouds, and you are there. You fly an F-15 with a real instrument panel, a radar that has to transmit to see, flak that shoots at what you tell it to, and an aeroplane that does not refill itself. Four missiles, 250 rounds and eleven minutes of fuel. The sortie ends when one of them does.' },
      { h: 'THE FRONT DOOR' },
      { p: 'There is no menu, and there is one sky. The game listens to the wire for a couple of seconds - every sky advertises itself once a second - and joins whatever it hears. Hears nothing, and it mints the sky itself. You press nothing.' },
      { p: 'Then you arrive as a spectator, into somebody else\'s fight: the orbit camera stands off a jet with a missile on its tail, because the war is running before anyone gets here. Space moves to the next one, and it moves on by itself after fifteen seconds if you don\'t. Arrows swing the camera, Z / X pull in and back off. Enter takes a jet - and you start it stopped on your own concrete, so the first thing your flight contains is a takeoff.' },
      ...ON_THIS_SITE,
      ...OWL2_FLYING,
      ...OWL2_KEYS,
    ],
  },

  owlfly3: {
    title: 'OWL FLY III',
    keys: 'Enter through the menus, then: B brakes, W/S throttle, A burner, arrows fly, Enter lock, Space gun, Tab/F8 Shilka, Esc pause, Alt-Q quit',
    blocks: [
      { h: 'WHAT THIS IS' },
      { p: 'OWL FLY II\'s war, flown on CGA, EGA, VGA and Hercules - pure 8086 assembly. The aeroplane, the keys and the war are OWL FLY II\'s; what this edition adds is every video card a PC could have, each with a cockpit drawn for it.' },
      { h: 'THE FRONT STEP' },
      { p: 'The game opens with SELECT VIDEO SYSTEM. The menu quizzes the hardware before offering, exactly as the metal would: every entry states its resolution and colours, and a card the machine has not got refuses the key. Every retro mode converts the same finished 256-colour frame; the cockpit on the retro cards is its own drawn artwork, baked offline - not a per-pixel conversion.' },
      { k: [
        ['1) HERCULES', '720x348 mono - marked NOT IN THIS MACHINE on the site\'s VGA. To fly it on a real Hercules: play owlfly3 --machine hercules in the terminal (Ctrl+`)'],
        ['2) CGA', '320x200, the classic palette 1 - cyan, magenta, white - with the cockpit redrawn as CGA line art; H swaps the hardware palette in flight to green/red/yellow and back'],
        ['3) EGA', '320x200, sixteen colours on ANY EGA - the 64K launch card included'],
        ['4) EGA', '640x350, EGA\'s best: sixteen curated colours, the drawn grey cockpit, no dither anywhere'],
        ['5) MCGA', '320x200, 256 colours - the frame straight, as on VGA'],
        ['6) VGA', '320x200, the game as born, 256 colours'],
        ['7) VGA', '640x480, sixteen colours at the crispest geometry of all'],
      ] },
      { p: 'Two more screens follow: GRAPHICS DETAIL - FULL, MEDIUM or LOW, conditions that skip work, not different games - and SELECT SOUND SYSTEM: the Sound Blaster\'s recorded turbine, the PC speaker bending one square wave, or no sound at all. ENTER on each screen takes the sensible answer. N switches day and night on every card.' },
      { p: 'Then, as in OWL FLY II, you arrive watching the war - PRESS ENTER TO JOIN takes a jet on your own concrete.' },
      { h: 'THE KEYS' },
      { p: 'The aeroplane is OWL FLY II\'s, key for key - all of them are below. One key is this edition\'s own: ESC pauses. The world stands still; the glass stays alive: F2-F7 keep switching views, the orbit camera still flies on the arrows, the radar and map still zoom, the MFD still pages. A red P sits on the panel while time is stopped - and it is the photographer\'s key: pause a dogfight, orbit it, frame the shot.' },
      { p: 'The other is the seat: Tab - or F8, or 0, for a browser that eats Tab - takes you out of the jet and into a Shilka on the ground, and back.' },
      { k: [
        ['<- / ->', 'in the Shilka: steer the hull'],
        ['^ / v', 'in the Shilka: forward / back'],
        ['A / D', 'turn the turret'],
        ['W / S', 'raise / lower the barrels'],
        ['Space', '(hold) fire'],
        ['F3', 'camera: cabin, follow, orbit; Q / E swing the orbit, Z / X its distance'],
      ] },
      { h: 'ON HERCULES' },
      { p: 'There was no colour on a Hercules and there is none here: what the card gives you is RESOLUTION - 720x348, twice a CGA\'s dots - and this game spends all of it. Brightness is dither density, and the cockpit ships pre-drawn in those densities, baked offline. On a Hercules machine the front step lands on it by itself, so ENTER through the three screens and you fly (for sound, the speaker is the honest pick there).' },
      ...ON_THIS_SITE,
      ...OWL2_FLYING,
      ...OWL2_KEYS,
    ],
  },

  owlfly: {
    title: 'OWL FLY',
    keys: 'arrows fly, W/S throttle, A burner, Enter lock, Space gun, Bksp missile, F2-F5 views, Esc quit',
    blocks: [
      { h: 'WHAT THIS IS' },
      { p: 'The combat flight simulator: a procedural island and a city that can be destroyed, two air forces of five aircraft types across a front line, homing missiles, a cockpit with a working radar, and a jet engine on the Sound Blaster.' },
      { h: 'FLYING' },
      { k: [
        ['<- / ->', 'bank left / right (numpad 4/6) - roll goes through 360 degrees, loops and barrel rolls work'],
        ['v / ^', 'pull the nose up / push it down, flight-sim yoke (numpad 2/8)'],
        ['Q / E, Z / C', 'rudder: a flat turn without banking (numpad 7/9)'],
        ['W / S', 'throttle up / down (+ / - too - some layouts eat +, W/S always work)'],
        ['A', 'afterburner - double thrust, drinks fuel'],
        ['hands off', 'the plane rights itself and trims to level'],
      ] },
      { h: 'FIGHTING' },
      { k: [
        ['Enter', 'lock the jet inside the aiming ring (TARGET / FRIEND + callsign); Enter on empty sky drops the lock'],
        ['Backspace', 'missile - 4 rails, homing on the lock, dumb-fire without one; one reloads every ~20 s'],
        ['Space', '(hold) cannon - real tracer rounds; hits land on whatever sits inside the ring; the belt refills while you hold fire'],
        ['M', 'right MFD: island map <-> sensor view of the locked target'],
        ['V', 'sound: all -> effects only -> silence (the S letter on the panel: amber / white / red)'],
      ] },
      { h: 'CAMERAS' },
      { k: [
        ['F2', 'cockpit on / off (the HUD tapes stay)'],
        ['F3', 'chase view: your own jet from behind, banking for real'],
        ['F4', 'orbit the locked target - the arrows steer the camera; if the target dies, the camera follows the debris down'],
        ['F5', 'arm the missile camera (M on the panel): the next launch is ridden to impact, 3 s of aftermath, then back'],
        ['N', 'day / night - the stars are a real celestial sphere'],
        ['Space', 'after GAME OVER: take a fresh jet'],
        ['Esc', 'quit to DOS'],
      ] },
      { h: 'THE WAR' },
      { p: 'Two squadrons in an attrition war over a procedural island: VIPERS - you plus 19 green squares - against 20 BANDIT yellow diamonds. The dead stay dead; when a team is wiped out the winner banner lights up and two fresh squadrons take the sky. The radar scoreboard shows this round\'s kills per team; the white number is your personal log and survives across rounds.' },
      { p: 'A jet soaks 2-5 cannon hits or one missile - and so do the buildings: a levelled block breaks into wall slabs, burns where it falls and stays a ruin. Falling wreckage can bring the neighbours down in a chain. Everything collides: jets with jets, jets with towers, wrecks with everything. Ramming works. Once.' },
      { p: 'You take 5 hits - the aiming ring flashes red and pips light up on the radar. The fifth, or a hillside, replays your last five seconds as a flashback, then the camera watches your jet come apart. GAME OVER - Space - again.' },
      { p: 'Watch the tapes: the red line on the speed tape is the stall, the one on the altitude tape is the terrain right below you. The gunsight bar always stays level with the horizon and its tick points at the sky; lose the horizon in a loop and a standby horizon appears at the ring.' },
      { h: 'THE PANEL' },
      { p: 'Left MFD - radar (heading-up): you are the centre tick, blips are jets (IFF-coloured, a dot above/below = higher/lower than you), amber sparks are missiles in the air, pips are your rails, the amber number is the cannon belt, red pips are your damage. Centre MFD - artificial horizon. Right MFD - the island map, or the target camera (M). Caution letters on the struts: Fuel, Stall, Terrain, Lock.' },
    ],
  },

  trainer: {
    title: 'The Flight School',
    keys: 'W/S throttle, arrows steer, Z/C rudder, F flaps, G gear, B brakes, V view, R reset, Esc quit',
    blocks: [
      { h: 'KEYS' },
      { p: 'W/S or +/- throttle, arrows steer, Z/C the rudder (on the ground, the nose-wheel trim); hold Shift and the arrows look around while the stick stays centred. F flaps (three settings in turn), G gear, B brakes, V view, O the canopy, R starts again, Esc back to DOS.' },
      { h: 'WHAT THIS IS' },
      { p: 'An airfield and a trainer: a numbered runway, taxiway, hangars, a control tower in obstruction stripes and a radar dish that turns. Take off, fly the pattern, put it back down on the numbers.' },
      { h: 'WHY IT IS WORTH A LOOK' },
      { p: 'Nobody is shooting at you, so the flight model is the whole subject - and it is a real one: rotation speed, the stall, and the ground cushion that floats you in the last few feet. Flaps, gear and brakes all do what they do on a real aeroplane. Learn the landing here and OWL FLY stops eating your jets on the way home.' },
    ],
  },

  wirecity: {
    title: 'WIRE CITY',
    keys: 'arrows steer - the horizon banks with you; Space after a crash, Esc quit',
    blocks: [
      { h: 'KEYS' },
      { p: 'The arrows steer; banking turns. After a crash Space flies again; Esc goes back to DOS. That is all of it.' },
      { h: 'WHAT THIS IS' },
      { p: 'The program that started the whole arcade: a night flight over a wireframe megacity, minted procedurally rather than drawn by hand. Arrows steer, the horizon banks with you, the towers slide past in the correct order.' },
      { h: 'WHY IT IS WORTH A LOOK' },
      { p: 'It is 5.5 KB and one source file - small enough to read end to end in a sitting, yet it already contains the three ideas every later machine here is built from: the fixed-point 3-D pipeline, hidden lines by the painter\'s algorithm, and a world generated from a seed instead of stored. Start here if you want to understand the rest.' },
    ],
  },

  multsoko: {
    title: 'MULTIPLAY SOKO',
    keys: 'arrows or W A S D walk and push, Space mine, Q/E turn, V isometric, Z whole level, R R anew, N N / P P',
    blocks: [
      { h: 'KEYS' },
      { p: 'The arrows, or W A S D, walk; walking into a crate pushes it, if the cell behind it is free. Space lays your mine where you stand. Q and E turn the view a quarter either way, and the arrows turn with it: up is always up the screen. V switches to the isometric view and back; Z shows the whole level or close up. R twice starts the level anew, N twice and P twice go to the next and the previous level - the first press only asks. Esc goes back to DOS.' },
      { h: 'WHAT THIS IS' },
      { p: 'Sokoban for up to eight: push every crate onto a red mark and the next level comes for everyone. A crate onto a mark scores +10, off one -10, a solved level +50 to every man in the warehouse. Everyone who plays it on the site works the same warehouse; the title asks your name, and the list under the floor shows every man, his name and his score - a star marks the host. Alone in the room, you open the warehouse yourself. The 60 levels are the ones of Base-Z-47.' },
      { h: 'MINES' },
      { p: 'Every man has one. Laid, it ticks five seconds - its seconds are on it - and then the nine cells round it blast: every man on them, whoever laid it, stands still for fifteen, his seconds over his head. The next mine is his a minute after he laid the last. The list shows each man\'s clock: M - he has a mine; M42 - forty-two seconds to the next; Z12 - twelve more seconds standing still.' },
      { h: 'ON THE NETWORK' },
      { p: 'One machine keeps the warehouse - the lowest name on the wire: the crates, the level, the men and the scores. The others send it their steps and draw the world it sends back twice a second, so two men can never push one crate two ways. A man not heard for 3 seconds leaves the floor; when the host goes quiet for 2, the next lowest carries on from the world it last drew.' },
      { h: 'WHY IT IS WORTH A LOOK' },
      { p: 'CGA: four colours, four pixels to a byte, and the even and odd rows in two separate banks. Every picture is text in ART.INC - one character a pixel - compiled at the start into a mask and an ink byte for each four pixels, and drawn back to front into a back buffer that the copy splits into the two banks. It began isometric, then went three-quarter, then straight down: the players got lost in the prettier views. The isometric one stayed behind V, and every view turns four ways - the grid is turned before it is drawn, so one renderer draws them all.' },
    ],
  },

  multsoko2: {
    title: 'MULTIPLAY SOKO II',
    keys: 'arrows or W A S D walk and push, Backspace or U a step back, Space mine, Q/E turn, V isometric, Z close up, R R anew, N N / P P',
    blocks: [
      { h: 'THE FIRST SCREEN' },
      { p: 'It asks three things, in text so that any card shows it: 1, 2, 3 or 4 picks the picture - EGA 640, sixteen colours at 640 by 200, the pictures drawn twice as fine across (recommended); EGA, the same at 320; CGA, four colours; Hercules, black and amber - a card this machine has not got refuses its key; 5 turns the sound on and off (a Sound Blaster at 220h); the letters you type are your name. Enter plays. By default the best card here and the sound on.' },
      { h: 'KEYS' },
      { p: 'The arrows, or W A S D, walk; walking into a crate pushes it, if the cell behind it is free. Backspace (delete on a Mac) or U takes your last step back, and the crate you pushed with it - up to 32 steps, your own only, and only while nobody has moved into the way since; the crate\'s points go back with it, the candies stay eaten. Space lays your mine where you stand. Q and E turn the view a quarter either way, and the arrows turn with it: up is always up the screen. V switches to the isometric view and back; Z shows the level close up, following you, and back to the whole of it. R twice starts the level anew, N twice and P twice go to the next and the previous level - the first press only asks. Esc goes back to DOS.' },
      { h: 'WHAT THIS IS' },
      { p: 'Sokoban for up to eight, in a castle: the whole level is always on the screen, the floor black and bare so nothing on it is lost. A crate onto a red mark scores +10, off one -10; every free cell starts with a candy, +1, +2 or +3; now and then a diamond grows out of the floor, +25, for fifteen seconds - step on it, or roll a crate onto it and the crate takes it for you. Half a minute or so apart an owl lands on a wall beside the floor and sits a quarter of a minute: walk into its wall and it is yours, +10. Every gain of five or more rises over the man who made it. A crate that can never go home again - in a corner, at the foot of a wall with no mark along it, locked in a square of crates and walls - is crossed in red, and the top line says what to do: Backspace, or R twice. When every crate is home the gate in the wall rises and the drawbridge comes down: walk out through it, +50, the first out +75. Fifteen seconds later the gate shuts, and whoever did most in the level stands on the podium. The 60 levels are the ones of Base-Z-47.' },
      { h: 'MINES' },
      { p: 'Every man has one. Laid, it ticks five seconds - its seconds are on it - and then the nine cells round it blast: every man on them, whoever laid it, stands still for fifteen, his seconds over his head. The next mine is his a minute after he laid the last. The list shows each man\'s clock: M - he has a mine; M42 - forty-two seconds to the next; Z12 - twelve more seconds standing still.' },
      { h: 'ON THE NETWORK' },
      { p: 'Everyone who plays it on the site is in the room multsok2 - not the first game\'s. One machine keeps the castle - the lowest name on the wire: the crates, the candies, the clocks, the men and the scores. The others send it their steps and draw the world it sends back, so two men can never push one crate two ways. A man not heard for 3 seconds leaves the floor; when the host goes quiet for 2, the next lowest carries on from the world it last drew.' },
      { h: 'WHY IT IS WORTH A LOOK' },
      { p: 'One picture, three cards. The game draws into a buffer of its own, two pixels to a byte, and each row it sends out only the stretch that changed since the last frame - so the rippling moat and the flickering torches cost a few bytes, not the screen. That stretch becomes four bit planes for the EGA (sixteen colours, our own on a VGA), two-bit pixels in two banks for the CGA (each colour a 2x2 half-tone), or dots for the Hercules (each colour a density). The castle is drawn once a level into a background - stones, growth, park - and the wind and the birds come from the WIRE CITY ring mixer, one Sound Blaster channel, no interrupts.' },
    ],
  },

  jet: demo('THE HANGAR', 'Up/Down cycle the air force, arrows spin, Space blows it apart',
    'A model viewer: all five aircraft the combat sims fly, each with a spec sheet drawn in the ROM font. Cycle the air force, spin any airframe in your hands, and press Space to blow it apart.',
    'This is where you can actually see what the games only flash past you at 400 knots - and where the depth sort proves itself: after the explosion the painter\'s algorithm keeps ordering every tumbling fragment correctly, with no z-buffer and no floating point. The airframes come through the Blender -> OBJ -> 8086 precompiler, so a new plane is a modelling job, not an assembly job.',
    'JET.ASM'),
  terra: demo('THE ISLAND FACTORY', 'any key mints a fresh island, Esc quits',
    'The terrain generator on its own, with the world stripped away: Diamond-Square wrapped on a torus, seeded from the clock. Any key mints a fresh island, ESC quits.',
    'Every island you have flown over here came out of this 5 KB of code, and it costs two bytes of seed instead of a megabyte of heightmap. That is also the trick behind instant multiplayer: OWL FLY II\'s sky advertisement carries the seed, your machine rebuilds the identical island, and you are in the same world as everyone else without downloading it.',
    'TERRA.ASM'),
  relief: demo('THE WIREFRAME RELIEF', 'Space takes off, arrows fly (down is nose up), H hides the hills, F engine, Esc lands',
    'A height-mapped island drawn as a lattice, and an aeroplane that never stops moving. The island is made on the spot by diamond-square, so it is a new one every time. You cannot fly through a hill.',
    'Press H. It switches on a floating horizon: one byte for each of the 320 screen columns, holding the highest thing drawn in that column so far, with the squares drawn from the eye outwards. A pixel shows only if it is above the skyline in its own column. That is the whole of hidden-line removal, and the far half of the picture stops being a fishing net. Now watch the frame counter: it falls from 70 to 35 in one step, because a frame that waits for the beam takes a whole number of retraces and there is no 60 to be had. Measured with that wait off, the hiding costs 76 against 60 - and against a plain line routine it is 60 against 53, which means hiding is faster. A pixel it throws out is a pixel it never writes.',
    'RELIEF.ASM'),
  smoke: demo('THE FIRE+SMOKE LAB', 'arrows orbit, +/- particles, W/S physics speed, [ ] zoom, F/G/V/B wind',
    'A particle laboratory: fire ages into spinning polygonal smoke puffs under buoyancy, drag, a vortex and turbulence. Orbit it with the arrows and tune the physics while it runs.',
    'Physics and rendering run on separate clocks, and the lab lets you drive them apart by hand: W/S scales the physics rate, + and - change the particle count, and the readout shows both rates live. It is the cheapest way to feel why a simulation that looks smooth on one machine goes wrong on a faster one - the lesson that keeps the games honest on hardware from the 8086 to WASM.',
    'SMOKE.ASM'),
  avio: demo('THE AVIONICS', 'arrows are the stick, +/- the throttle - fly the instruments themselves',
    'An instrument panel with no world attached: artificial horizon, speed and altitude tapes with the red stall line, a compass, and a toy flight model underneath. The arrows are the stick.',
    '3.5 KB, and it teaches the half of a flight sim that is not 3-D at all. Fly it on the instruments alone and you learn to read the glass the way the combat sims expect: the horizon in a roll, the speed bleeding off toward the red line, the altitude tape unwinding. Same tapes, same logic, no terrain in the way.',
    'AVIO.ASM'),
};

/** Words to lines of at most `width`; a word longer than that is cut. */
function wrap(text, width, indent = '') {
  const out = [];
  let line = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    const room = width - (out.length ? indent.length : 0);
    if (!line) line = word;
    else if (line.length + 1 + word.length <= room) line += ` ${word}`;
    else { out.push(line); line = word; }
    while (line.length > width - indent.length && line.length > 1) { out.push(line.slice(0, width - indent.length)); line = line.slice(width - indent.length); }
  }
  if (line) out.push(line);
  return out.map((l, i) => (i ? indent + l : l));
}

/** A manual laid out for a window `width` columns wide: its text, one line each. */
export function manualLines(key, width) {
  const m = MANUALS[key];
  if (!m) return [];
  const lines = [];
  for (const b of m.blocks) {
    if (b.h) { if (lines.length) lines.push(''); lines.push(b.h); lines.push(''); }
    else if (b.p) { lines.push(...wrap(b.p, width)); lines.push(''); }
    else if (b.k) {
      // A key column as wide as the longest key it holds (at most a third of the window), the words hanging after it.
      const col = Math.min(Math.floor(width / 3), Math.max(...b.k.map(([k]) => k.length)) + 2);
      for (const [k, what] of b.k) {
        const words = wrap(what, width - col);
        lines.push(`${k.padEnd(col)}${words[0] ?? ''}`.slice(0, width));
        for (const w of words.slice(1)) lines.push(' '.repeat(col) + w);
      }
      lines.push('');
    }
  }
  while (lines.length && lines.at(-1) === '') lines.pop();
  return lines;
}
