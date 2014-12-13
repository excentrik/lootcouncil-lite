(Adapted from the original author - Blacksen) - Excentrik

Loot Council is a new mod designed to help loot councils with a solid voting interface. Whenever a raid assistant or guild leader starts a loot council session for a specific item, members can either whisper their current item to the initiator, link in officer chat, link in guild chat, or link in raid chat. The mod will process the item and display it in an easy to use table. Officers can then vote for or against various members and see how other officers have voted.

The primary goal of Loot Council is to have it customizable to fit your guild's needs. You can control votes being private/public. You can have officers only be able to cast one vote or multiple. You can control which chat channels detect messages. You can allow or disallow officers to vote for themselves. You can set up which ranks are part of the council. You can set up a list of raiders that can disenchant gear.

I love feedback and take it very seriously! Many features have been implemented 3-4 days after being requested! So please, leave feedback and report bugs. I'll try to get to them all as best I can. (This continues to apply to the current maintainer)

Demo Video / Tutorial: https://www.youtube.com/watch?v=UJ5ysv8F3X4

Vote Modes:
You can mix and match the vote modes to fit your council's needs!
Private Vote Mode: All votes cast are private and cannot be seen by other council members.
Single Vote Mode: All council members are restricted to one vote per person.
Spec Detection Mode: Whenever someone links an item, you can detect the key phrases "main", "off", "bis", "4set", "2set" or "xmog". If someone says "MAINSPEC," it'll see the phrase "MAIN" and flag it as main spec.
Restrict Self Voting: Prevent council members from voting on themselves.
One LC per raid: Allows different loot councils in the same guild for different raids.

Commands:

- /ltc - Shows all commands
- /ltc start (itemlink) - Starts a loot council session for the linked item.
- /ltc end - Attempts to end/abort the current loot council session.
- /ltc show - Shows the main loot council window
- /ltc hide - Hides the main loot council window
- /ltc rank - Opens the rank interface.
- /ltc add (name) (itemlink) - Manually add player with (name) and item (itemlink) to the consideration
- /ltc config - Shows the options panel
- /ltc test - Open the test frame
- /ltc channel channel_name - Changes the default communication channel (use default to revert to OFFICER channel)


Usage:
1) All officers make sure to set the correct minimum rank by typing /ltc rank and using the window.
2) When an item drops, type /ltc start (itemlink) where itemlink is the link to the item.
3) Anyone who wants the item can either link their current item in officer chat OR whisper the person who started the session.
4) The window should automatically populate.
5) Left click the voting options to cast your vote. If you want to give a reason for your vote, right click.
6) Once voting is done, the person who started the session needs to hit "Abort" or type /ltc end - Note that sessions are automatically ended if you use the "award" feature.

TODO:

- Better support for version detection (allow appended strings)
- Automatic detection of enchanters in the raid group if the enchanters list is empty or has "auto"
- Support for a note after the spec specification when whispering an item
- Attendance tracking, visualization and editing
- Better (more consistent) handling of character names to avoid problems with "name-realm" format
- Information about characters ilvl
- Adding council member by hand
- More?