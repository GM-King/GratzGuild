"""Behaviour and UI lifecycle tests. Requires lupa with its Lua 5.1 runtime."""
from pathlib import Path
import json
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / "PetMaxxing" / ".test-runtime"))
from lupa.lua51 import LuaRuntime

def runtime(ui=False, screen=(1920, 1080)):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests" / "wow_mock.lua").read_text(encoding="utf-8"))
    lua.globals().UIParent.SetSize(lua.globals().UIParent, *screen)
    gg = lua.table()
    loader = lua.eval("function(source, gg) assert(loadstring(source))('GratzGuild', gg) end")
    for name in ("Core.lua", "SoundCatalog.lua", "Main.lua", "Celebrations.lua", "UI.lua") if ui else ("Core.lua", "SoundCatalog.lua", "Main.lua", "Celebrations.lua"):
        loader((ROOT / name).read_text(encoding="utf-8"), gg)
    lua.globals().gg = gg
    lua.execute("""
        mockRoster = {
            {name='Celebrant-TestRealm', online=true, guid='Player-1-self'},
            {name='Thrall-TestRealm', online=true, guid='Player-1-thrall', class='SHAMAN'},
            {name='Jaina-TestRealm', online=false, guid='Player-1-jaina', class='MAGE'},
        }
        gg.eventFrame.scripts.OnEvent(gg.eventFrame, 'ADDON_LOADED', 'GratzGuild')
        gg.eventFrame.scripts.OnEvent(gg.eventFrame, 'PLAYER_LOGIN')
    """)
    return lua, gg

class TrackingTests(unittest.TestCase):
    def setUp(self): self.lua, self.gg = runtime()
    def run_lua(self, script): self.lua.execute(script)

    def test_baseline_charge_offline_and_self_exclusion(self):
        self.run_lua("""
            local g = gg.Main.guild
            assert(g.dings == 0)
            gg.Main.LevelUp(41)
            assert(g.members['thrall-testrealm'].debt == 1)
            assert(g.members['jaina-testrealm'].debt == 1)
            assert(g.members['celebrant-testrealm'].debt == 0)
            assert(#mockChat == 1 and mockChat[1].text == 'Ding!' and mockChat[1].channel == 'GUILD')
            gg.Main.LevelUp(41)
            assert(#mockChat == 1 and g.dings == 1)
            assert(mockOffline == false)
        """)

    def test_repeated_messages_repay_in_window_without_banked_credit(self):
        self.run_lua("""
            gg.Main.LevelUp(43)
            local m = gg.Main.guild.members['thrall-testrealm']
            for i=1,4 do
                mockTime = mockTime + 2
                mockIncoming(gg, 'CHAT_MSG_WHISPER', 'Gratz!', 'Thrall', i, 'Player-1-thrall')
            end
            assert(m.debt == 0 and m.repayments == 3)
            gg.Main.LevelUp(44)
            assert(m.debt == 1)
        """)

    def test_secret_text_is_not_inspected_by_helpers(self):
        self.run_lua("""
            local secret = setmetatable({}, {
                __tostring = function() error('secret text was converted') end,
                __index = function() error('secret text was indexed') end,
            })
            issecretvalue = function(value) return rawequal(value, secret) end
            assert(gg.Core.Plain(secret) == '')
            assert(not gg.Core.IsReport(secret))
            assert(not gg.Core.IsGrats(secret))
            assert(not gg.Core.IsDing(secret))
            local grats, ding = gg.Core.Classify(secret)
            assert(not grats and not ding)
            assert(gg.Core.IsGrats('Gratz!'))
            issecretvalue = nil
            assert(gg.Core.IsGrats('Gratz!'))
        """)

    def test_secret_chat_fields_are_ignored_before_parsing_or_buffering(self):
        self.run_lua("""
            gg.Main.LevelUp(43)
            local g, m = gg.Main.guild, gg.Main.guild.members['thrall-testrealm']
            local report = gg.Core.IsReport
            gg.Core.IsReport = function() error('restricted chat reached parser') end
            for _, ready in ipairs({true, false}) do
                gg.Main.ready = ready
                for field = 1, 5 do
                    local values = {'grats', 'Thrall', 123, 'Player-1-thrall', 456}
                    local secret = values[field]
                    issecretvalue = function(value) return value == secret end
                    gg.Main.Chat('CHAT_MSG_GUILD', values[1], values[2],
                        nil,nil,nil,nil,nil,nil,nil,nil,values[3],values[4],values[5])
                    gg.Main.HandleChat('CHAT_MSG_GUILD', values[1], values[2],
                        values[3], values[4], values[5])
                    assert(#g.pending == 0 and #gg.Main.queue == 0)
                    assert(next(gg.Main.seen) == nil)
                    assert(m.debt == 3 and m.repayments == 0)
                    assert(g.celebration.count == 0)
                end
            end
            gg.Core.IsReport, issecretvalue, gg.Main.ready = report, nil, true
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'grats', 'Thrall', 123, 'Player-1-thrall')
            assert(m.debt == 2 and m.repayments == 1)
        """)

    def test_recognition_and_false_positives(self):
        self.run_lua(r"""
            for _, word in ipairs({'GRATZ!', 'graaaaatzzzz', 'congrats mate', 'congratulations!!!', 'GZZ', 'grz', 'grattis'}) do
                assert(gg.Core.IsGrats(word), word)
            end
            for _, word in ipairs({'ding', 'grateful', 'disgrats', 'congratulationship', 'gzipped', '|Hitem:123|h[Gratz Sword]|h'}) do
                assert(not gg.Core.IsGrats(word), word)
            end
            assert(gg.Core.IsGrats('Well done mate!', 'well done'))
            assert(not gg.Core.IsGrats('well doneish', 'well done'))
            assert(not gg.Core.IsGrats('unrelated', '\n!!!\n'))
            assert(gg.Core.IsDing('Diiiing! 42'))
            assert(not gg.Core.IsDing('standing or dinghy'))
        """)

    def test_new_default_phrases(self):
        self.run_lua("""
            for _, text in ipairs({'Gratez!', 'GRAAATEZZZ', 'gratez mate'}) do
                assert(gg.Core.IsGrats(text))
            end
            for _, text in ipairs({'BIG DINGUS', 'biiig   diiinguus!!!', 'Big, dingus!'}) do
                assert(gg.Core.IsDing(text))
                local grats, ding = gg.Core.Classify(text)
                assert(not grats and ding)
            end
            for _, text in ipairs({'dingus', 'big dinguses', 'gratezilla'}) do
                assert(not gg.Core.IsGrats(text) and not gg.Core.IsDing(text))
            end
            gg.Main.LevelUp(41)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'Gratez!', 'Thrall', 101)
            assert(gg.Main.guild.members['thrall-testrealm'].debt == 0)
            assert(gg.Main.guild.celebration.count == 1)
            local before = #mockChat
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'BIG DINGUS', 'Thrall', 102)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'BIG DINGUS', 'Thrall', 103)
            gg.Main.Tick(2)
            assert(#mockChat == before + 1)
        """)

    def test_event_dedup_and_multiple_words_count_once(self):
        self.run_lua("""
            gg.Main.LevelUp(44)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'grats gratz gz', 'Thrall', 10)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'grats gratz gz', 'Thrall', 10)
            assert(gg.Main.guild.members['thrall-testrealm'].debt == 3)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'grats gratz gz', 'Thrall', 11)
            assert(gg.Main.guild.members['thrall-testrealm'].debt == 2)
        """)

    def test_non_guild_and_own_messages_ignored(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            mockIncoming(gg, 'CHAT_MSG_SAY', 'gratz', 'Stranger', 1)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'Ding!', 'Celebrant', 2, 'Player-1-self')
            assert(gg.Main.guild.members['thrall-testrealm'].debt == 1)
            assert(#gg.Main.queue == 0)
        """)

    def test_autograts_any_channel_cooldown_and_no_loops(self):
        self.run_lua("""
            gg.Core.db.settings.autoMessage = 'Gratz, {name}!'
            mockIncoming(gg, 'CHAT_MSG_WHISPER', 'ding 41', 'Thrall', 1)
            mockAdvance(gg, 0.2)
            assert(#mockChat == 1 and mockChat[1].text == 'Gratz, Thrall!' and mockChat[1].channel == 'GUILD')
            mockIncoming(gg, 'CHAT_MSG_YELL', 'DING!', 'Thrall', 2)
            assert(#gg.Main.queue == 0)
            mockAdvance(gg, 31)
            mockIncoming(gg, 'CHAT_MSG_SAY', 'ding', 'Thrall', 3)
            mockAdvance(gg, 2)
            assert(#mockChat == 2)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'Gratz on your ding!', 'Jaina', 4)
            assert(#gg.Main.queue == 0)
            mockIncoming(gg, 'CHAT_MSG_GUILD', '[GratzGuild] ding', 'Jaina', 5)
            assert(#gg.Main.queue == 0)
        """)

    def test_disabled_auto_drops_pending_reply(self):
        self.run_lua("""
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'ding', 'Thrall', 1)
            gg.Core.db.settings.autoEnabled = false
            mockAdvance(gg, 2)
            assert(#mockChat == 0)
        """)

    def test_roster_delay_queues_exactly_once(self):
        self.run_lua("""
            local g = gg.Main.guild
            mockRoster[3].missing = true
            gg.Main.LevelUp(41)
            assert(#g.pending == 1 and g.dings == 0)
            assert(g.members['jaina-testrealm'].active)
            mockRoster[3].missing = false
            gg.Main.CaptureRoster()
            assert(#g.pending == 0 and g.dings == 1)
            gg.Main.CaptureRoster()
            assert(g.members['jaina-testrealm'].debt == 1)
        """)

    def test_delayed_roster_preserves_ding_and_reply_order(self):
        self.run_lua("""
            local g = gg.Main.guild
            mockRoster[3].missing = true
            gg.Main.LevelUp(41)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz', 'Thrall', 1)
            mockIncoming(gg, 'CHAT_MSG_WHISPER', 'gratz', 'Thrall', 2)
            gg.Main.LevelUp(42)
            mockRoster[3].missing = false
            gg.Main.CaptureRoster()
            assert(g.dings==2 and g.members['thrall-testrealm'].debt==1)
            assert(g.members['jaina-testrealm'].debt==2 and #g.pending==0)
        """)

    def test_roster_filter_events_do_not_recurse_and_pending_retries(self):
        self.run_lua("""
            local changes=mockFilterChanges
            for i=1,10 do gg.eventFrame.scripts.OnEvent(gg.eventFrame, 'GUILD_ROSTER_UPDATE') end
            assert(mockFilterChanges==changes)
            mockRoster[3].missing=true
            gg.Main.LevelUp(41)
            mockRoster[3].missing=false
            mockAdvance(gg,6)
            assert(#gg.Main.guild.pending==0 and gg.Main.guild.dings==1)
        """)

    def test_startup_waits_for_login(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((ROOT / 'tests' / 'wow_mock.lua').read_text(encoding='utf-8'))
        gg = lua.table()
        loader = lua.eval("function(source, gg) assert(loadstring(source))('GratzGuild', gg) end")
        for name in ('Core.lua', 'SoundCatalog.lua', 'Main.lua', 'Celebrations.lua', 'UI.lua'):
            loader((ROOT / name).read_text(encoding='utf-8'), gg)
        lua.globals().gg = gg
        lua.execute("""
            mockPlayer, mockPlayerGUID = nil, nil
            gg.eventFrame.scripts.OnEvent(gg.eventFrame, 'ADDON_LOADED', 'GratzGuild')
            assert(not gg.Main.initialized and not gg.UI.frame)
            mockPlayer, mockPlayerGUID = 'Celebrant', 'Player-1-self'
            gg.eventFrame.scripts.OnEvent(gg.eventFrame, 'PLAYER_LOGIN')
            assert(gg.Main.initialized and gg.UI.frame)
        """)

    def test_departures_rejoin_and_new_members(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            local original = mockRoster[3]
            table.remove(mockRoster, 3)
            gg.Main.CaptureRoster()
            gg.Main.LevelUp(42)
            assert(gg.Main.guild.members['jaina-testrealm'].debt == 1)
            mockRoster[3] = original
            mockRoster[4] = {name='Baine-TestRealm', online=false}
            gg.Main.CaptureRoster()
            assert(gg.Main.guild.members['jaina-testrealm'].active)
            assert(gg.Main.guild.members['baine-testrealm'].debt == 0)
        """)

    def test_shared_alt_reload_and_guild_separation(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            local old = gg.Main.guild
            mockPlayer, mockPlayerGUID, mockLevel = 'MyAlt', 'Player-1-alt', 20
            mockRoster[4] = {name='MyAlt-TestRealm', online=true, guid='Player-1-alt'}
            gg.Main.Initialize()
            assert(gg.Main.guild == old and old.members['thrall-testrealm'].debt == 1)
            gg.Main.LevelUp(21)
            assert(old.members['thrall-testrealm'].debt == 2)
            assert(old.members['celebrant-testrealm'].debt == 0 and old.members['myalt-testrealm'].debt == 0)
            gg.Main.Initialize()
            assert(old.dings == 2)
            mockGuild = 'Another Guild'
            gg.Main.Context(); gg.Main.CaptureRoster()
            assert(gg.Main.guild ~= old and gg.Main.guild.members['thrall-testrealm'].debt == 0)
        """)

    def test_report_selection_order_pacing_cancel_and_failure(self):
        self.run_lua("""
            local g = gg.Main.guild
            gg.Core.Correct(g, 'thrall-testrealm', 2, time())
            local lines = gg.Core.Report(g)
            assert(#lines == 3 and lines[1]:find('Gratz Debt Ledger',1,true))
            assert(lines[2]=='[GratzGuild] Thrall-TestRealm - 2 grats owed')
            assert(lines[3]=='[GratzGuild] Jaina-TestRealm - 0 grats owed')
            g.members['jaina-testrealm'].selected = false
            lines = gg.Core.Report(g)
            assert(not lines[1]:find('Jaina'))
            gg.Core.Select(g, 'none'); assert(#gg.Core.Report(g) == 0)
            gg.Core.Select(g, 'debt'); assert(g.members['thrall-testrealm'].selected)
            assert(not g.members['jaina-testrealm'].selected)
            assert(gg.Main.StartReport({'one', 'two', 'three'}))
            mockAdvance(gg, 0.2); assert(#mockChat == 1)
            mockAdvance(gg, 0.2); assert(#mockChat == 1)
            mockAdvance(gg, 2); assert(#mockChat == 2)
            gg.Main.CancelReport(); mockAdvance(gg, 2); assert(#mockChat == 2)
            mockChatFailure = true
            gg.Main.StartReport({'four'}); mockAdvance(gg, 2)
            assert(gg.Main.report == nil and #gg.Main.queue == 0 and mockLastPrint:find('Blocked by client'))
        """)

    def test_guild_leave_cancels_old_queue(self):
        self.run_lua("""
            gg.Main.StartReport({'old guild message'})
            mockGuild = nil; gg.Main.Context()
            mockAdvance(gg, 3)
            assert(#mockChat == 0 and gg.Main.guild == nil)
        """)

    def test_message_length_markup_and_utf8(self):
        core = self.gg.Core
        self.assertEqual(core.UTF8Cut('abéz', 3), 'ab')
        self.assertEqual(core.UTF8Cut('abéz', 4), 'abé')
        self.assertEqual(core.Message('Ding {level}! {name}\n|cffffffffHi|r', 'Al%t', 42), 'Ding 42! Al%t Hi')
        self.assertLessEqual(len(core.Message('é' * 200, 'test', 1).encode()), 255)
        self.run_lua("""
            for i=1,100 do
                local key = 'guildmate'..i..'-testrealm'
                gg.Main.guild.members[key] = {name='Guildmate'..i..'-TestRealm', debt=i, active=true, selected=true}
            end
            local lines = gg.Core.Report(gg.Main.guild)
            assert(#lines > 1)
            for _, line in ipairs(lines) do assert(#line <= 255 and line:find('[GratzGuild]', 1, true)) end
        """)

    def test_permission_and_empty_messages(self):
        self.run_lua("""
            mockCanSpeak = false
            local ok, reason = gg.Main.Send('Ding!')
            assert(not ok and reason:find('rank') and #mockChat == 0)
            mockCanSpeak = true
            assert(not gg.Main.Send('  '))
        """)

    def test_battlenet_requires_matching_guid(self):
        self.run_lua("""
            gg.Main.LevelUp(42)
            C_BattleNet = {GetAccountInfoByID=function() return {gameAccountInfo={clientProgram='WoW',playerGuid='Player-1-thrall'}} end}
            gg.Main.Chat('CHAT_MSG_BN_WHISPER', 'grats', 'AccountName', nil,nil,nil,nil,nil,nil,nil,nil,1,nil,100)
            assert(gg.Main.guild.members['thrall-testrealm'].debt == 1)
            C_BattleNet.GetAccountInfoByID=function() return {gameAccountInfo={clientProgram='WoW',characterName='Thrall'}} end
            gg.Main.Chat('CHAT_MSG_BN_WHISPER', 'grats', 'AccountName', nil,nil,nil,nil,nil,nil,nil,nil,2,nil,100)
            assert(gg.Main.guild.members['thrall-testrealm'].debt == 1)
        """)

class CelebrationTests(unittest.TestCase):
    def setUp(self): self.lua, self.gg = runtime(ui=True)
    def run_lua(self, script): self.lua.execute(script)

    def test_5_10_15_sound_and_artwork_pairing_without_open_ledger(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            for i=1,4 do mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz!', 'Thrall', i) end
            assert(#mockSounds==0)
            mockIncoming(gg, 'CHAT_MSG_WHISPER', 'gratz!', 'Thrall', 5)
            local s=gg.Celebrations
            assert(#mockSounds==1 and s.active.tier==5)
            assert(mockSounds[1].file:find('sounds\\\\cheer\\\\',1,true))
            assert(s.portrait.texture=='Interface\\\\AddOns\\\\GratzGuild\\\\Media\\\\Celebrations\\\\'..s.active.portrait)
            assert(s.frame:IsShown() and not gg.UI.frame:IsShown())
            assert(mockSounds[1].channel=='Master')
            for i=6,10 do mockIncoming(gg, 'CHAT_MSG_SAY', 'gz', 'Thrall', i) end
            assert(#mockSounds==1 and #s.queue==1)
            mockAdvance(gg,6)
            assert(#mockSounds==2 and s.active.tier==10)
            assert(mockSounds[2].file:find('sounds\\\\congrats\\\\',1,true))
            for i=11,15 do mockIncoming(gg, 'CHAT_MSG_YELL', 'congrats', 'Thrall', i) end
            mockAdvance(gg,6)
            assert(#mockSounds==3 and s.active.tier==15)
            local finale=s.active.rare and 'for_the_horde_rare.mp3' or 'for_the_horde.mp3'
            assert(mockSounds[3].file:find(finale,1,true))
            assert(s.active.sound.portrait=='ForTheHorde')
            for i=16,25 do mockIncoming(gg, 'CHAT_MSG_GUILD', 'grats', 'Thrall', i) end
            assert(#mockSounds==3 and #s.queue==0)
            assert(gg.Main.guild.celebration.count==25)
        """)

    def test_only_eligible_messages_count_and_duplicates_do_not(self):
        self.run_lua("""
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz', 'Thrall', 1)
            assert(not gg.Main.guild.celebration and #mockSounds==0)
            gg.Main.LevelUp(41)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz grats congrats', 'Thrall', 2)
            mockIncoming(gg, 'CHAT_MSG_WHISPER', 'gratz grats congrats', 'Thrall', 2)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz', 'Stranger', 3)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz', 'Celebrant', 4)
            mockIncoming(gg, 'CHAT_MSG_GUILD', '[GratzGuild] gratz', 'Jaina', 5)
            assert(gg.Main.guild.celebration.count==1)
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz', 'Thrall', 6)
            assert(gg.Main.guild.celebration.count==2 and gg.Main.guild.members['thrall-testrealm'].debt==0)
            gg.Core.MarkOwn('Thrall', 'TestRealm')
            mockIncoming(gg, 'CHAT_MSG_GUILD', 'gratz', 'Thrall', 7)
            assert(gg.Main.guild.celebration.count==2)
        """)

    def test_next_ding_resets_count_and_cancels_old_sound_queue(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            for i=1,10 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(gg.Celebrations.active and #gg.Celebrations.queue==1)
            local oldID=gg.Main.guild.celebration.id
            gg.Main.LevelUp(42)
            assert(gg.Main.guild.celebration.id~=oldID and gg.Main.guild.celebration.count==0)
            assert(not gg.Celebrations.active and #gg.Celebrations.queue==0)
            assert(#mockStoppedSounds==1)
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',11)
            local newID=gg.Main.guild.celebration.id
            gg.Main.LevelUp(42)
            assert(gg.Main.guild.celebration.count==1 and gg.Main.guild.celebration.id==newID)
        """)

    def test_disabled_milestones_do_not_replay_but_later_tier_can_fire(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            mockClick(gg.UI.celebrationsCheck,false)
            for i=1,5 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(#mockSounds==0 and gg.Main.guild.celebration.fired[5])
            mockClick(gg.UI.celebrationsCheck,true)
            for i=6,10 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(#mockSounds==1 and gg.Celebrations.active.tier==10)
            mockClick(gg.UI.celebrationsCheck,false)
            assert(not gg.Celebrations.active and not gg.Celebrations.frame:IsShown())
        """)

    def test_previews_do_not_change_real_counter_and_can_be_dismissed(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            for i=1,4 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            gg.UI.SetTab('celebrations')
            assert(mockPreview(gg,15))
            assert(gg.Main.guild.celebration.count==4 and not gg.Main.guild.celebration.fired[15])
            assert(gg.Celebrations.active.preview and gg.Celebrations.active.sound.portrait=='ForTheHorde')
            mockClick(gg.Celebrations.close)
            assert(not gg.Celebrations.active and not gg.Celebrations.frame:IsShown())
            gg.Core.db.settings.reducedMotion=true
            mockPreview(gg,5)
            assert(not gg.Celebrations.fadeIn.playing)
            SlashCmdList.GRATZGUILD('celebrations'); assert(gg.UI.tab=='celebrations')
        """)

    def test_delayed_roster_does_not_count_replies_for_previous_ding(self):
        self.run_lua("""
            mockRoster[3].missing=true
            gg.Main.LevelUp(41)
            for i=1,4 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            gg.Main.LevelUp(42)
            for i=5,9 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            mockRoster[3].missing=false
            gg.Main.CaptureRoster()
            assert(gg.Main.guild.celebration.count==5 and #mockSounds==1)
            assert(gg.Celebrations.active.tier==5)
        """)

    def test_guild_change_and_alliance_cancel_horde_celebrations(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            for i=1,5 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(gg.Celebrations.active)
            mockGuild='New Guild'; gg.Main.Context(); gg.Main.CaptureRoster()
            assert(not gg.Celebrations.active and #gg.Celebrations.queue==0)
            mockFaction='Alliance'; gg.Main.LevelUp(42)
            assert(not gg.Main.guild.celebration)
            assert(not mockPreview(gg,5))
        """)

    def test_sound_failure_keeps_artwork_and_reports_locally(self):
        self.run_lua("""
            mockSoundFailure=true
            mockPreview(gg,5)
            assert(gg.Celebrations.frame:IsShown() and gg.Celebrations.active)
            assert(mockLastPrint:find('could not play'))
        """)

    def test_random_pool_can_select_different_voices_with_matching_portraits(self):
        self.run_lua("""
            local random=math.random
            math.random=function() return 1 end
            mockPreview(gg,5)
            local first=gg.Celebrations.active.sound
            assert(first.portrait=='SkyborneFemale')
            math.random=function(n) return n end
            mockPreview(gg,5)
            local last=gg.Celebrations.active.sound
            assert(first.file~=last.file and last.portrait=='UndeadMale')
            assert(gg.Celebrations.portrait.texture:find(last.portrait,1,true))
            math.random=random
        """)

    def test_rare_chance_is_five_of_one_hundred_for_every_portrait(self):
        self.run_lua("""
            local random=math.random
            local portraits=0
            for base in pairs(gg.Celebrations.rarePortraits) do
                portraits=portraits+1
                local rares=0
                for roll=1,100 do
                    math.random=function(n) assert(n==100); return roll end
                    local portrait, rare=gg.Celebrations.PickPortrait({portrait=base})
                    assert(portrait==base..(rare and 'Rare' or ''))
                    assert(rare==(roll<=5))
                    if rare then rares=rares+1 end
                end
                assert(rares==5)
            end
            assert(portraits==11)
            math.random=function() error('Unknown portraits must not roll a missing asset') end
            local name,rare=gg.Celebrations.PickPortrait({portrait='NewVoice'})
            assert(name=='NewVoice' and not rare)
            math.random=random
        """)

    def test_rare_portrait_stays_selected_during_refresh_and_preserves_voice(self):
        self.run_lua("""
            local random=math.random
            local rolls=0
            math.random=function(n)
                if n==100 then rolls=rolls+1; return 5 end
                return 7
            end
            mockPreview(gg,5)
            local s=gg.Celebrations
            assert(s.active.sound.portrait=='OrcMale' and s.active.portrait=='OrcMaleRare')
            assert(s.active.rare and s.lastRare and rolls==1)
            assert(mockSounds[1].file:find('OrcMaleCheer01.ogg',1,true))
            gg.UI.SetTab('celebrations')
            for i=1,20 do gg.UI.Refresh(); s.Update(0) end
            assert(rolls==1 and s.portrait.texture:find('OrcMaleRare',1,true))
            assert(next(gg.Core.db.collection)==nil)
            math.random=function(n) return n==100 and 6 or 7 end
            mockPreview(gg,5); gg.UI.Refresh()
            assert(not s.active.rare and s.active.portrait=='OrcMale' and not s.lastRare)
            assert(next(gg.Core.db.collection)==nil)
            math.random=random
        """)

    def test_horde_rare_variant_and_cancelled_queue_selection(self):
        self.run_lua("""
            local random=math.random
            local rolls=0
            math.random=function(n)
                if n==100 then rolls=rolls+1; return 1 end
                return 1
            end
            mockPreview(gg,15)
            assert(rolls==1 and gg.Celebrations.active.portrait=='ForTheHordeRare')
            assert(mockSounds[1].file:find('for_the_horde_rare.mp3',1,true))
            gg.Main.LevelUp(41)
            for i=1,10 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(rolls==2 and #gg.Celebrations.queue==1)
            gg.Main.LevelUp(42)
            mockAdvance(gg,10)
            assert(rolls==2 and not gg.Celebrations.active and #gg.Celebrations.queue==0)
            math.random=random
        """)

    def test_reload_retains_count_and_fired_tiers(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            for i=1,6 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            mockLevel=41
            gg.Celebrations.Stop()
        """)
        replacement = self.lua.table()
        loader = self.lua.eval("function(source, gg) assert(loadstring(source))('GratzGuild', gg) end")
        for name in ('Core.lua', 'SoundCatalog.lua', 'Main.lua', 'Celebrations.lua', 'UI.lua'):
            loader((ROOT / name).read_text(encoding='utf-8'), replacement)
        self.lua.globals().gg = replacement
        self.run_lua("""
            gg.eventFrame.scripts.OnEvent(gg.eventFrame,'ADDON_LOADED','GratzGuild')
            gg.eventFrame.scripts.OnEvent(gg.eventFrame,'PLAYER_LOGIN')
            assert(gg.Main.guild.celebration.count==6 and gg.Main.guild.celebration.fired[5])
            assert(not gg.Celebrations.active)
            for i=7,10 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(gg.Celebrations.active.tier==10 and #mockSounds==2)
        """)

    def test_rare_horde_audio_tracks_the_art_roll_and_actual_duration(self):
        self.run_lua("""
            local random=math.random
            math.random=function() return 5 end
            mockPreview(gg,15)
            local s=gg.Celebrations
            assert(s.active.portrait=='ForTheHordeRare')
            assert(s.active.playbackSound==gg.Sounds.hordeRare)
            assert(mockSounds[#mockSounds].file:find('for_the_horde_rare.mp3',1,true))
            assert(s.active.untilTime==mockTime+math.max(5,gg.Sounds.hordeRare.duration+0.7))
            math.random=function() return 6 end
            mockPreview(gg,15)
            assert(s.active.portrait=='ForTheHorde' and s.active.playbackSound==gg.Sounds.horde)
            assert(mockSounds[#mockSounds].file:find('for_the_horde.mp3',1,true))
            assert(gg.Sounds.horde.file=='sounds\\\\for_the_horde.mp3')
            math.random=random
        """)

class ReplyWindowTests(unittest.TestCase):
    def setUp(self): self.lua, self.gg = runtime(ui=True)
    def run_lua(self, script): self.lua.execute(script)

    def test_five_minute_boundary_blocks_repayments_and_milestones(self):
        self.run_lua("""
            gg.Main.LevelUp(43)
            local g=gg.Main.guild
            local start=g.replyWindow.at
            assert(not gg.Core.CanCredit(g,start-1))
            assert(gg.Core.CanCredit(g,start+299.9))
            assert(not gg.Core.CanCredit(g,start+300))
            mockAdvance(gg,299)
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',1)
            assert(g.members['thrall-testrealm'].debt==2 and g.celebration.count==1)
            mockAdvance(gg,1)
            for i=2,16 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i) end
            assert(g.members['thrall-testrealm'].debt==2 and g.celebration.count==1)
            assert(#mockSounds==0 and gg.Core.ReplyRemaining(g,time())==0)
            gg.UI.Toggle(true); gg.UI.SetTab('celebrations')
            assert(gg.UI.celebrationCounter:GetText():find('WINDOW CLOSED',1,true))
            assert(not gg.Core.Repay(g,'thrall-testrealm',time(),'GUILD'))
        """)

    def test_next_ding_reopens_window_but_duplicate_level_does_not(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            mockAdvance(gg,301)
            gg.Main.LevelUp(41)
            assert(not gg.Core.CanCredit(gg.Main.guild,time()))
            gg.Main.LevelUp(42)
            assert(gg.Core.ReplyRemaining(gg.Main.guild,time())==300)
            mockIncoming(gg,'CHAT_MSG_WHISPER','gratz','Thrall',1)
            assert(gg.Main.guild.members['thrall-testrealm'].debt==1)
            assert(gg.Main.guild.celebration.count==1)
        """)

    def test_arrival_timestamp_is_captured_once_at_the_boundary(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            local g=gg.Main.guild
            local original=gg.Main.Now
            local calls=0
            gg.Main.Now=function()
                calls=calls+1
                return g.replyWindow.at+(calls==1 and 299 or 300)
            end
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',1)
            assert(g.members['thrall-testrealm'].debt==0 and g.celebration.count==1)
            assert(calls==1)
            gg.Main.Now=original
        """)

    def test_buffered_replies_use_arrival_time_and_original_window(self):
        self.run_lua("""
            mockRoster[3].missing=true
            gg.Main.LevelUp(41)
            mockTime=mockTime+299
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',1)
            mockTime=mockTime+2
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',2)
            assert(#gg.Main.guild.pending==2)
            mockRoster[3].missing=false
            gg.Main.CaptureRoster()
            assert(gg.Main.guild.members['thrall-testrealm'].debt==0)
            assert(gg.Main.guild.celebration.count==1)
            assert(not gg.Core.CanCredit(gg.Main.guild,time()))
        """)

    def test_previous_window_buffered_reply_does_not_repay_new_ding(self):
        self.run_lua("""
            mockRoster[3].missing=true
            gg.Main.LevelUp(41)
            mockTime=mockTime+299
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',1)
            mockTime=mockTime+2
            mockRoster[3].missing=false
            gg.Main.LevelUp(42)
            assert(gg.Main.guild.members['thrall-testrealm'].debt==1)
            assert(gg.Main.guild.members['jaina-testrealm'].debt==2)
            assert(gg.Main.guild.celebration.count==0)
        """)

    def test_login_and_alt_switch_do_not_reopen_an_expired_window(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            local original=gg.Main.guild.replyWindow.at
            mockAdvance(gg,301)
            mockPlayer,mockPlayerGUID,mockLevel='MyAlt','Player-1-alt',20
            mockRoster[4]={name='MyAlt-TestRealm',online=true,guid='Player-1-alt'}
            gg.Main.Initialize()
            assert(gg.Main.guild.replyWindow.at==original)
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',1)
            assert(gg.Main.guild.members['thrall-testrealm'].debt==1)
            assert(gg.Main.guild.celebration.count==0)
            gg.Main.LevelUp(21)
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',2)
            assert(gg.Main.guild.members['thrall-testrealm'].debt==1)
        """)

    def test_legacy_saved_ding_migration_does_not_extend_deadline(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            local g=gg.Main.guild
            local original=g.celebration.at
            g.replyWindow=nil
            mockTime=mockTime+301
            gg.Core.GetGuild(mockGuild,mockRealm)
            assert(g.replyWindow.at==original and g.replyWindow.expiresAt==original+300)
            assert(not gg.Core.CanCredit(g,time()))
        """)

    def test_auto_grats_other_dings_still_works_after_reply_window(self):
        self.run_lua("""
            gg.Main.LevelUp(41)
            mockAdvance(gg,301)
            mockIncoming(gg,'CHAT_MSG_GUILD','ding 42','Thrall',1)
            mockAdvance(gg,2)
            assert(mockChat[#mockChat].text=='Gratz!')
            assert(gg.Main.guild.celebration.count==0)
        """)

class UITests(unittest.TestCase):
    def test_sending_preview_remains_the_queued_snapshot(self):
        lua, gg = runtime(ui=True)
        lua.execute("""
            gg.Main.LevelUp(42)
            gg.UI.Toggle(true); gg.UI.SetTab('announcements')
            local original=gg.UI.previewLines[2]
            mockClick(gg.UI.reportSend)
            gg.Core.Correct(gg.Main.guild, 'thrall-testrealm', 99, time())
            gg.UI.Refresh()
            assert(gg.UI.previewLines[2]==original and gg.Main.queue[2].text==original)
            gg.Main.CancelReport(); gg.UI.Refresh()
            assert(gg.UI.previewLines[2]~=original)
        """)

    def test_correction_requires_confirmation(self):
        lua, gg = runtime(ui=True)
        lua.execute("""
            gg.Main.LevelUp(42)
            local m=gg.Main.guild.members['thrall-testrealm']
            local function clickCaption(caption)
                for _, widget in ipairs(mockObjects) do
                    if widget.parent==gg.UI.modal and widget.kind=='Button' and widget.caption:GetText()==caption then
                        mockClick(widget); return
                    end
                end
                error('Missing button '..caption)
            end
            gg.UI.Correction('thrall-testrealm')
            clickCaption('Forgive debt')
            assert(m.debt==2)
            clickCaption('Cancel'); assert(m.debt==2)
            gg.UI.Correction('thrall-testrealm'); clickCaption('Forgive debt')
            clickCaption('Confirm'); assert(m.debt==0)
        """)

    def test_window_fits_smaller_screen(self):
        lua, gg = runtime(ui=True, screen=(1280, 720))
        self.assertLessEqual(gg.UI.frame.height * gg.UI.frame.scale, 680)
        self.assertLessEqual(gg.UI.frame.width * gg.UI.frame.scale, 1240)

    def test_ui_lifecycle_controls_and_all_tabs(self):
        lua, gg = runtime(ui=True)
        lua.execute("""
            gg.UI.Toggle(true)
            assert(gg.UI.frame:IsShown() and UISpecialFrames[1]=='GratzGuildFrame')
            gg.Main.LevelUp(41)
            gg.UI.Refresh()
            assert(gg.UI.debtStat:GetText()=='2')
            mockClick(gg.UI.rows[1].selected, false)
            assert(#gg.Core.Members(gg.Main.guild, {selected=true})==1)
            gg.UI.SetTab('announcements')
            assert(#gg.UI.previewLines==2)
            mockClick(gg.UI.reportSend)
            assert(gg.Main.report and gg.Main.report.total==2)
            mockClick(gg.UI.reportCancel)
            assert(not gg.Main.report)
            gg.UI.SetTab('settings')
            gg.UI.dingMessage:SetText('Ding {level}!')
            gg.UI.autoMessage:SetText('Gratz {name}!')
            assert(gg.UI.defaultGrats:GetText():find('gratez', 1, true))
            assert(gg.UI.defaultDings:GetText():find('BIG DINGUS', 1, true))
            for _, phrase in ipairs(gg.Core.DefaultGratsPhrases) do
                assert(gg.UI.defaultGrats:GetText():find(phrase, 1, true))
            end
            gg.UI.extraPhrases:SetText('well done')
            gg.UI.phraseTest:SetText('well done mate')
            assert(gg.UI.phraseResult:GetText():find('repays'))
            gg.UI.exclusions:SetText('Jaina-TestRealm')
            gg.UI.SaveSettings()
            assert(gg.Core.db.settings.dingMessage=='Ding {level}!')
            assert(gg.Core.db.exclusions['jaina-testrealm'])
            gg.UI.SetTab('ledger')
            gg.UI.search:SetText('Thrall')
            assert(gg.UI.rows[1].name:GetText()=='Thrall-TestRealm' and not gg.UI.rows[2]:IsShown())
            gg.UI.Correction('thrall-testrealm'); assert(gg.UI.modal:IsShown())
            gg.UI.Confirm('Confirm', 'Confirm correction', function() gg.Core.Correct(gg.Main.guild, 'thrall-testrealm', 0, time()) end)
            gg.UI.History(); assert(gg.UI.modal:IsShown())
            gg.UI.Celebrate(42)
            assert(gg.UI.murlocPulse.playing)
            mockClick(gg.UI.motionCheck, true)
            assert(not gg.UI.murlocPulse.playing)
            gg.UI.scaleSlider:SetValue(0.8); assert(gg.UI.frame.scale==0.8)
            SlashCmdList.GRATZGUILD('resetui'); assert(gg.UI.frame.scale==1)
            SlashCmdList.GRATZGUILD('settings'); assert(gg.UI.tab=='settings')
            SlashCmdList.GRATZGUILD('announce'); assert(gg.UI.tab=='announcements')
            mockGuild=nil; gg.Main.Context(); gg.UI.Refresh()
            assert(not gg.UI.reportSend:IsEnabled())
        """)

    def test_scroll_and_selected_list_persist(self):
        lua, gg = runtime(ui=True)
        lua.execute("""
            for i=1,30 do mockRoster[#mockRoster+1] = {name='Raider'..i..'-TestRealm', online=i%2==0} end
            gg.Main.CaptureRoster(); gg.UI.Toggle(true)
            gg.UI.rowScroll:SetValue(15)
            assert(gg.UI.offset==15)
            local key=gg.UI.rows[1].key
            mockClick(gg.UI.rows[1].selected, false)
            gg.Main.CaptureRoster()
            assert(gg.Main.guild.members[key].selected==false)
            gg.UI.search:SetText('nomatch')
            assert(gg.UI.maxOffset==0 and gg.UI.empty:IsShown())
        """)

class PackagingTests(unittest.TestCase):
    def test_rare_artwork_files_mapping_and_original_bytes(self):
        import hashlib
        import struct
        manifest=json.loads((ROOT/'Media'/'Celebrations'/'RareArtworkManifest.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest['chancePerCelebration'], 0.05)
        self.assertEqual(len(manifest['assets']), 11)
        _, gg = runtime()
        self.assertEqual({a['character'] for a in manifest['assets']}, set(gg.Celebrations.rarePortraits.keys()))
        for asset in manifest['assets']:
            png=ROOT/'Media'/'Celebrations'/asset['png']
            self.assertEqual(hashlib.sha256(png.read_bytes()).hexdigest(), asset['sourceSHA256'])
            self.assertEqual(asset['texture'], asset['character']+'Rare.tga')
            raw=(ROOT/'Media'/'Celebrations'/asset['texture']).read_bytes()
            size=1024 if asset['character']=='ForTheHorde' else 512
            self.assertEqual(struct.unpack_from('<HH',raw,12),(size,size))
            self.assertEqual(raw[2],2)
            self.assertEqual(raw[16],32)
            self.assertEqual(raw[17]&15,8)
            alpha=raw[18+3:18+size*size*4:4]
            self.assertEqual(max(alpha),255)
            if asset['sourceMode']=='RGBA': self.assertEqual(min(alpha),0)

    def test_all_supplied_sounds_have_corresponding_horde_art(self):
        import hashlib
        import struct
        metadata = json.loads((ROOT / 'Media' / 'SoundCatalog.json').read_text(encoding='utf-8'))
        catalog = metadata['catalog']
        self.assertEqual(len(catalog['cheer']), 21)
        self.assertEqual(len(catalog['congrats']), 24)
        for group in ('cheer', 'congrats'):
            supplied = {(hashlib.sha256(p.read_bytes()).hexdigest()) for p in (ROOT / 'sounds' / group).glob('*.ogg')}
            self.assertEqual(supplied, {r['sha256'] for r in catalog[group]})
        voices = catalog['cheer'] + catalog['congrats'] + [catalog['horde'],catalog['hordeRare']]
        for entry in voices:
            path = ROOT / entry['file'].replace('\\', '/')
            self.assertTrue(path.is_file())
            self.assertGreater(entry['duration'], 0)
            portrait = ROOT / 'Media' / 'Celebrations' / (entry['portrait'] + '.tga')
            self.assertTrue(portrait.is_file(), entry['portrait'])
            raw = portrait.read_bytes()
            size = 1024 if entry['portrait'] == 'ForTheHorde' else 512
            self.assertEqual(raw[2], 2)
            self.assertEqual(struct.unpack_from('<HH', raw, 12), (size, size))
            self.assertEqual(raw[16], 32)
            self.assertEqual(raw[17] & 15, 8)
        self.assertEqual(catalog['horde']['file'], 'sounds\\for_the_horde.mp3')
        self.assertEqual(catalog['horde']['portrait'], 'ForTheHorde')
        self.assertEqual(catalog['hordeRare']['file'], 'sounds\\for_the_horde_rare.mp3')
        self.assertEqual(catalog['hordeRare']['portrait'], 'ForTheHorde')
        self.assertNotEqual(catalog['hordeRare']['sha256'], catalog['horde']['sha256'])
        for entry in voices:
            if 'BloodElf' in entry['file']:
                self.assertTrue(entry['portrait'].startswith('Skyborne'))

    def test_runtime_files_and_texture_format(self):
        import struct
        toc = (ROOT / 'GratzGuild.toc').read_text(encoding='utf-8')
        self.assertIn('## Interface: 16001', toc)
        self.assertIn('## SavedVariables: GratzGuildDB', toc)
        for line in toc.splitlines():
            if line.strip() and not line.startswith('#'):
                self.assertTrue((ROOT / line.strip().replace('\\', '/')).is_file(), line)
        for name, dimensions in {'Murloc': (512, 512), 'Horde': (1024, 512), 'MurlocIcon': (64, 64)}.items():
            raw = (ROOT / 'Media' / f'{name}.tga').read_bytes()
            self.assertEqual(raw[2], 2, 'Texture must be uncompressed true-colour TGA')
            self.assertEqual(struct.unpack_from('<HH', raw, 12), dimensions)
            self.assertEqual(raw[16], 32)
            self.assertEqual(raw[17] & 0x0F, 8, 'Texture must retain 8-bit alpha')
            pixels = raw[18:18 + dimensions[0] * dimensions[1] * 4]
            self.assertEqual(min(pixels[3::4]), 0)
            self.assertEqual(max(pixels[3::4]), 255)

class RequestedFixTests(unittest.TestCase):
    def setUp(self): self.lua, self.gg = runtime(ui=True)
    def run_lua(self, script): self.lua.execute(script)

    def test_self_guid_aliases_clear_old_debt_and_ignore_chat(self):
        self.run_lua("""
            local c,m=gg.Core,gg.Main
            mockRoster[1].name='Celebrant-OtherRealm'
            m.guild.members['celebrant-otherrealm']={debt=9,selected=true,guid=mockPlayerGUID}
            m.CaptureRoster(); m.LevelUp(41)
            local own=m.guild.members['celebrant-otherrealm']
            assert(own.debt==0 and not own.selected)
            assert(not c.Correct(m.guild,'celebrant-otherrealm',4,m.Now()))
            for i,name in ipairs({'Celebrant','Celebrant-TestRealm','Celebrant-OtherRealm'}) do
                mockIncoming(gg,'CHAT_MSG_GUILD','Ding!',name,i,mockPlayerGUID)
                mockIncoming(gg,'CHAT_MSG_WHISPER','gratz',name,i+10,mockPlayerGUID)
            end
            mockAdvance(gg,2)
            assert(#mockChat==1 and m.guild.celebration.count==0 and own.debt==0)
        """)

    def test_minimap_outside_scaled_map_and_icon_fits(self):
        self.run_lua("""
            local b=gg.UI.minimap
            assert(b.parent==UIParent and b.icon.width==20 and b.width==32)
            gg.Core.db.settings.minimapAngle=0
            Minimap:SetSize(220,220); Minimap:SetScale(1.2)
            b.scripts.OnUpdate(b,0.6)
            assert(b.points[1][4]==156 and b.points[1][5]==0)
            Minimap:Hide(); assert(not b:IsShown())
            Minimap:Show(); assert(b:IsShown())
        """)

    def test_popup_guide_visibility_resize_move_and_reset(self):
        self.run_lua("""
            local s=gg.Celebrations
            assert(not s.editor:IsShown() and s.frame.scale==0.75)
            assert(s.editor.width==262.5 and s.editor.height==322.5)
            assert(s.editor.points[1][4]==220 and s.editor.points[1][5]==160)
            assert(s.frame.points[1][2]==s.editor)
            gg.UI.Toggle(true); assert(s.editor:IsShown())
            gg.UI.SetTab('collection'); assert(s.editor:IsShown())
            s.editorGrip.scripts.OnMouseDown(s.editorGrip,'LeftButton')
            s.editor:SetSize(350,450)
            assert(s.frame.scale==1 and s.editor.height==430)
            s.editor.GetCenter=function() return 1200,700 end
            s.editorGrip.scripts.OnMouseUp(s.editorGrip,'LeftButton')
            assert(gg.Core.db.settings.celebrationPosition[3]==240)
            assert(gg.Core.db.settings.celebrationPosition[4]==160)
            s.ResetLayout(); assert(s.frame.scale==0.75 and s.editor.points[1][4]==220)
            gg.UI.Toggle(false); assert(not s.editor:IsShown())
        """)

    def test_only_fixed_orc_test_and_no_collection_unlock(self):
        self.run_lua("""
            local s=gg.Celebrations
            assert(s.Preview==nil)
            math.random=function() return 1 end
            mockClick(gg.UI.popupTest)
            assert(s.active.preview and s.active.portrait=='OrcMale' and not s.active.rare)
            assert(next(gg.Core.db.collection)==nil)
            assert(s.title:GetText()=='TEST POPUP')
        """)

    def test_collection_locked_entries_do_not_reveal_art(self):
        self.run_lua("""
            local u=gg.UI
            assert(#gg.Celebrations.CollectionEntries()==22)
            for page=1,4 do
                u.collectionPage=page; u.RefreshCollection()
                for _,card in ipairs(u.collectionCards) do
                    if card.entry then
                        assert(not card.enabled and not card.art.shown and card.art.texture==nil)
                        assert(card.requirement:GetText():find('grats',1,true))
                        assert(not u.ShowCollected(card.entry))
                    end
                end
            end
        """)

    def test_real_rare_popup_unlocks_only_shown_variant_and_persists(self):
        self.run_lua("""
            local s,c,m=gg.Celebrations,gg.Core,gg.Main
            math.random=function(n) return n==100 and 1 or 7 end
            m.LevelUp(41)
            for i=1,5 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i,'Player-1-thrall') end
            assert(s.active.portrait=='OrcMaleRare')
            assert(c.db.collection.OrcMaleRare and not c.db.collection.OrcMale)
            local saved=c.db; c.Initialize(saved)
            gg.UI.collectionPage=1; gg.UI.RefreshCollection()
            assert(gg.UI.collectionCards[2].art.shown and gg.UI.collectionCards[2].enabled)
            local sounds=#mockSounds
            assert(gg.UI.ShowCollected(gg.UI.collectionCards[2].entry))
            assert(#mockSounds==sounds)
            s.Stop(); m.LevelUp(42)
            assert(c.db.collection.OrcMaleRare)
        """)

    def test_cancelled_or_disabled_popups_do_not_unlock(self):
        self.run_lua("""
            local s,c,m=gg.Celebrations,gg.Core,gg.Main
            m.LevelUp(41); s.Test()
            s.Enqueue(gg.Sounds.horde,15,m.guild.celebration.id,false)
            s.Stop(); assert(next(c.db.collection)==nil)
            c.db.settings.celebrationsEnabled=false
            for i=1,15 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',i,'Player-1-thrall') end
            assert(next(c.db.collection)==nil)
        """)


class PresentationRefinementTests(unittest.TestCase):
    def setUp(self): self.lua, self.gg = runtime(ui=True)

    def test_guide_hidden_during_test_and_restored_only_when_interface_open(self):
        self.lua.execute("""
            local s=gg.Celebrations
            gg.UI.Toggle(true); assert(s.editor:IsShown())
            mockClick(gg.UI.popupTest); assert(s.frame:IsShown() and not s.editor:IsShown())
            gg.UI.Toggle(false); gg.UI.Toggle(true); assert(not s.editor:IsShown())
            s.StopCurrent(); assert(s.editor:IsShown())
            s.Test(); gg.UI.Toggle(false); s.StopCurrent(); assert(not s.editor:IsShown())
            gg.UI.Toggle(true); s.Test(); mockAdvance(gg,30); assert(s.editor:IsShown())
        """)

    def test_large_report_confirm_cancel_and_snapshot(self):
        self.lua.execute("""
            for i=1,9 do mockRoster[#mockRoster+1]={name='Guildie'..i..'-TestRealm',online=true} end
            gg.Main.CaptureRoster(); gg.UI.Toggle(true); gg.UI.SetTab('announcements')
            local function choose(caption)
                for _,w in ipairs(mockObjects) do
                    if w.parent==gg.UI.modal and w.kind=='Button' and w.caption:GetText()==caption then mockClick(w); return end
                end
                error('Missing confirmation button')
            end
            assert(#gg.UI.previewLines==12)
            mockClick(gg.UI.reportSend); assert(gg.UI.modal:IsShown() and not gg.Main.report and #gg.Main.queue==0)
            choose('Cancel'); assert(not gg.Main.report and #mockChat==0)
            mockClick(gg.UI.reportSend)
            local snapshot=gg.UI.previewLines[2]
            gg.Core.Correct(gg.Main.guild,'thrall-testrealm',99,time())
            gg.Core.Select(gg.Main.guild,'none'); gg.UI.Refresh()
            choose('Confirm'); assert(gg.Main.report and gg.Main.report.total==12)
            assert(gg.Main.queue[2].text==snapshot)
            for i=1,12 do mockAdvance(gg,2) end
            assert(#mockChat==12 and mockChat[1].text:find('Gratz Debt Ledger',1,true))
        """)

    def test_ten_names_send_without_warning(self):
        self.lua.execute("""
            for i=1,8 do mockRoster[#mockRoster+1]={name='Guildie'..i..'-TestRealm',online=true} end
            gg.Main.CaptureRoster(); gg.UI.Toggle(true); gg.UI.SetTab('announcements'); mockClick(gg.UI.reportSend)
            assert(gg.Main.report and gg.Main.report.total==11 and not gg.UI.modal)
        """)

    def test_locked_collection_labels_remain_secret_and_no_proc_chance(self):
        self.lua.execute("""
            for page=1,4 do
                gg.UI.collectionPage=page; gg.UI.RefreshCollection()
                for _,card in ipairs(gg.UI.collectionCards) do
                    if card.entry then
                        assert(card.nameText:GetText()=='Undiscovered celebration')
                        assert(not card.requirement:GetText():find('%%') and not card.requirement:GetText():find('rare'))
                    end
                end
            end
            gg.Core.db.collection.OrcMale={at=time()}
            gg.UI.collectionPage=1; gg.UI.RefreshCollection()
            assert(gg.UI.collectionCards[1].nameText:GetText()=='Orc male')
        """)

    def test_all_popups_use_feelgood_messages_including_rare_finale(self):
        self.lua.execute("""
            local s=gg.Celebrations
            for _,sound in ipairs(gg.Sounds.cheer) do
                s.Stop(); s.Enqueue(sound,5,nil,true,sound.portrait)
                assert(not s.subtitle:GetText():find(sound.label,1,true))
                assert(#s.subtitle:GetText()>10)
                if sound.portrait=='TrollMale' then assert(s.subtitle:GetText()=='You da best, mon!') end
            end
            s.Stop(); s.Enqueue(gg.Sounds.horde,15,nil,true,'ForTheHordeRare')
            assert(s.subtitle:GetText()=='Your Horde is cheering for you!')
        """)


class PerformanceTests(unittest.TestCase):
    def setUp(self):
        self.lua, self.gg = runtime(ui=True)
        self.lua.execute("""
            for i=4,1000 do mockRoster[i]={name='Guildie'..i..'-TestRealm',online=true,guid='Player-'..i} end
            gg.Main.CaptureRoster(); gg.Main.LevelUp(41); mockAdvance(gg,0.2)
            counts={sort=0,report=0,roster=0,norm=0,collection=0,ledger=0,mark=0}
            local sort,report,roster,norm=table.sort,gg.Core.Report,GetGuildRosterInfo,gg.Core.Normalized
            table.sort=function(...) counts.sort=counts.sort+1; return sort(...) end
            gg.Core.Report=function(...) counts.report=counts.report+1; return report(...) end
            GetGuildRosterInfo=function(...) counts.roster=counts.roster+1; return roster(...) end
            gg.Core.Normalized=function(...) counts.norm=counts.norm+1; return norm(...) end
            local coll,ledger,mark=gg.UI.RefreshCollection,gg.UI.RefreshLedger,gg.Core.MarkOwn
            gg.UI.RefreshCollection=function(...) counts.collection=counts.collection+1; return coll(...) end
            gg.UI.RefreshLedger=function(...) counts.ledger=counts.ledger+1; return ledger(...) end
            gg.Core.MarkOwn=function(...) counts.mark=counts.mark+1; return mark(...) end
        """)

    def test_hidden_countdown_and_open_fresh_data(self):
        self.lua.execute("""
            for i=1,60 do mockAdvance(gg,1) end
            assert(counts.sort==0 and counts.report==0 and counts.collection==0)
            mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Thrall',1)
            mockAdvance(gg,1)
            assert(gg.Main.dirty and counts.ledger==0)
            gg.UI.Toggle(true)
            assert(gg.UI.gratsStat:GetText()=='Grats this ding: 1' and counts.ledger>0)
        """)

    def test_visible_countdown_only_updates_celebrations(self):
        self.lua.execute("""
            gg.UI.Toggle(true); gg.UI.SetTab('celebrations'); mockAdvance(gg,1)
            for k in pairs(counts) do counts[k]=0 end
            for i=1,60 do mockAdvance(gg,1) end
            assert(counts.sort==0 and counts.report==0 and counts.ledger==0 and counts.collection==0)
            assert(gg.UI.celebrationCounter:GetText():find('3:59 LEFT',1,true))
        """)

    def test_roster_burst_and_sustained_updates(self):
        self.lua.execute("""
            mockOffline=true; mockAdvance(gg,2)
            for i=1,100 do gg.eventFrame.scripts.OnEvent(gg.eventFrame,'GUILD_ROSTER_UPDATE') end
            assert(counts.roster==0)
            mockAdvance(gg,0.25); assert(counts.roster==1000 and counts.mark==0)
            for i=1,30 do
                gg.eventFrame.scripts.OnEvent(gg.eventFrame,'GUILD_ROSTER_UPDATE')
                mockAdvance(gg,0.1)
            end
            assert(counts.roster<=4000)
            mockAdvance(gg,1)
            assert(not gg.Main.rosterDue)
        """)

    def test_chat_cache_and_live_classification(self):
        self.lua.execute("""
            gg.Core.db.settings.extraPhrases='well done'
            mockIncoming(gg,'CHAT_MSG_CHANNEL','ordinary message','Stranger',1)
            counts.norm=0
            for i=1,100 do mockIncoming(gg,'CHAT_MSG_CHANNEL','ordinary message','Stranger',i+1) end
            assert(counts.norm==100)
            counts.norm=0
            mockIncoming(gg,'CHAT_MSG_GUILD','well done','Thrall',200,'Player-1-thrall')
            assert(counts.norm==1 and gg.Main.guild.celebration.count==1)
            gg.Core.db.settings.extraPhrases='nice work'
            mockIncoming(gg,'CHAT_MSG_GUILD','well done','Thrall',201)
            mockIncoming(gg,'CHAT_MSG_GUILD','nice work','Thrall',202)
            assert(gg.Main.guild.celebration.count==2)
        """)

    def test_filter_events_and_unchanged_minimap_do_not_repeat_work(self):
        self.lua.execute("""
            local original=SetGuildRosterShowOffline
            SetGuildRosterShowOffline=function(value)
                original(value)
                gg.eventFrame.scripts.OnEvent(gg.eventFrame,'GUILD_ROSTER_UPDATE')
            end
            mockAdvance(gg,2); gg.Main.CaptureRoster()
            local reads=counts.roster
            mockAdvance(gg,2)
            assert(counts.roster==reads and not gg.Main.rosterDue and mockOffline==false)
            local b=gg.UI.minimap
            local clear=b.ClearAllPoints
            local resets=0
            b.ClearAllPoints=function(...) resets=resets+1; return clear(...) end
            for i=1,10 do b.scripts.OnUpdate(b,0.6) end
            assert(resets==0)
            gg.Core.db.settings.minimapAngle=90
            b.scripts.OnUpdate(b,0.6)
            assert(resets==1)
        """)

    def test_cached_cross_realm_names_keep_resolution_rules(self):
        self.lua.execute("""
            mockRoster[#mockRoster+1]={name='Unique-OtherRealm',online=true,guid='Player-unique'}
            mockRoster[#mockRoster+1]={name='Ambiguous-One',online=true}
            mockRoster[#mockRoster+1]={name='Ambiguous-Two',online=true}
            gg.Main.CaptureRoster()
            assert(gg.Main.ResolveSender('Unique')=='unique-otherrealm')
            assert(not gg.Main.ResolveSender('Ambiguous'))
            assert(gg.Main.ResolveSender('Ambiguous-One')=='ambiguous-one')
            assert(gg.Main.ResolveSender('Unrelated','Player-unique')=='unique-otherrealm')
        """)

    def test_sender_cache_refresh_and_context_reset(self):
        self.lua.execute("""
            assert(gg.Main.ResolveSender(nil,'Player-1-thrall')=='thrall-testrealm')
            table.remove(mockRoster,2); gg.Main.CaptureRoster()
            assert(not gg.Main.ResolveSender(nil,'Player-1-thrall'))
            gg.Main.ScheduleRoster(); mockGuild='New Guild'; gg.Main.Context()
            assert(not gg.Main.rosterDue and not gg.Main.ResolveSender(nil,'Player-1-jaina'))
        """)


def export_layout():
    lua, gg = runtime(ui=True)
    lua.execute("""
        local names={'Thrall','Jaina','Baine','Voljin','Saurfang','Rexxar','Sylvanas','Garrosh','Chen','Nazgrel','Eitrigg','Zuljin'}
        local classes={'SHAMAN','MAGE','WARRIOR','HUNTER','WARRIOR','HUNTER','HUNTER','WARRIOR','DRUID','SHAMAN','WARRIOR','HUNTER'}
        mockRoster={mockRoster[1]}
        for i,name in ipairs(names) do mockRoster[#mockRoster+1]={name=name..'-TestRealm',online=i%3~=0,level=39+i,class=classes[i]} end
        gg.Main.CaptureRoster()
        for i,name in ipairs(names) do
            local m=gg.Main.guild.members[name:lower()..'-testrealm']
            m.debt=math.max(0,7-math.floor(i/2)); m.selected=i%3~=0
        end
        gg.Main.guild.repayments=27
        gg.UI.Toggle(true)
    """)
    output = ROOT / "tests" / "output"
    output.mkdir(exist_ok=True)
    for tab in ('ledger', 'announcements', 'celebrations', 'collection', 'settings', 'popup'):
        if tab == 'popup':
            gg.UI.frame.Hide(gg.UI.frame)
            gg.Celebrations.Test()
        else:
            gg.UI.SetTab(tab)
        records = []
        for obj in lua.globals().mockObjects.values():
            record = {}
            for field in ('id', 'kind', 'name', 'template', 'shown', 'enabled', 'width', 'height', 'text', 'fontSize', 'justifyH', 'texture', 'normalTexture', 'strata', 'checked', 'value'):
                value = obj[field]
                if isinstance(value, (str, int, float, bool)): record[field] = value
            record['parent'] = obj.parent.id if obj.parent else None
            for field in ('background', 'border', 'textColor'):
                if obj[field]: record[field] = list(obj[field].values())
            record['points'] = [[p[1], p[2].id if p[2] else None, p[3], p[4], p[5]] for p in obj.points.values()]
            records.append(record)
        (output / f'{tab}-layout.json').write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Exported actual Lua UI layouts to {output}')

if __name__ == '__main__':
    if '--export-layout' in sys.argv: export_layout()
    else: unittest.main()
