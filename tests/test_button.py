import unittest
from test_gratzguild import runtime
class ButtonTests(unittest.TestCase):
    def check(self, code):
        lua, _ = runtime(ui=True)
        lua.execute(code)
    def test_stack_combat_expiry(self):
        self.check('''local b=gg.GratzButton
        b.Combat(true)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockAdvance(gg,90)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Jaina',2)
        assert(b.remaining==40 and not b.frame:IsShown() and #mockChat==0)
        b.Press(); assert(#mockChat==0)
        b.Combat(false); assert(b.frame:IsShown())
        mockAdvance(gg,39); assert(b.remaining==1)
        mockAdvance(gg,1); assert(#b.entries==0 and not b.frame:IsShown())''')
    def test_combined_and_double_click(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Jaina',2)
        assert(b.remaining==40)
        b.Press(); b.Press()
        assert(#mockChat==1 and mockChat[1].text=='Gratz!')
        assert(gg.Main.guild.celebration.source=='gratzButton')
        assert(not gg.Main.guild.replyWindow and gg.Main.guild.dings==0)''')
    def test_failure_retry(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockChatFailure=true; b.Press()
        assert(#b.entries==1 and not gg.Main.guild.celebration)
        mockAdvance(gg,1); mockChatFailure=false; b.Press()
        assert(#b.entries==0 and #mockChat==1)''')
    def test_reward_deadline_and_milestones(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Jaina',1)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',2); b.Press()
        local s=gg.Main.guild.celebration; local deadline=s.expiresAt
        for i=3,17 do mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Jaina',i) end
        assert(s.count==15 and s.fired[5] and s.fired[10] and s.fired[15])
        mockAdvance(gg,31)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',18); b.Press()
        assert(s.expiresAt==deadline and s.count==15)
        mockAdvance(gg,269)
        mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Jaina',19); assert(s.count==15)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',20); b.Press()
        assert(gg.Main.guild.celebration.id~=s.id and gg.Main.guild.celebration.count==0)''')
    def test_preview_sound_no_rewards(self):
        self.check('''local b=gg.GratzButton
        b.Preview(); b.Press(); mockAdvance(gg,.13)
        assert(#mockSounds==1 and mockSounds[1].file:find('ParryWoodHitWood',1,true))
        mockAdvance(gg,.2); assert(#mockSounds==1 and #mockChat==0 and not gg.Main.guild.celebration)''')
    def test_roster_buffer_no_preclick_credit(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        gg.Main.ready=false; mockRoster[3].missing=true
        mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Jaina',2)
        b.Press(); mockRoster[3].missing=false; gg.Main.CaptureRoster()
        assert(gg.Main.guild.celebration.count==0)
        mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Jaina',3)
        assert(gg.Main.guild.celebration.count==1)''')
    def test_routing_and_renumbering(self):
        self.check('''local b=gg.GratzButton
        local id=7
        GetChannelName=function(name) return id,'Friends' end
        local d=b.Destination('CHAT_MSG_CHANNEL','Thrall',3,'Friends')
        local target
        C_ChatInfo.SendChatMessage=function(text,kind,lang,t) target=t end
        assert(gg.Main.Send('hi',d) and target==7)
        id=0; assert(not gg.Main.Send('hi',d))
        assert(b.Destination('CHAT_MSG_PARTY_LEADER').kind=='PARTY')
        assert(b.Destination('CHAT_MSG_TEXT_EMOTE').kind=='EMOTE')
        C_BattleNet={SendWhisper=function(t,text) target=t end}
        assert(gg.Main.Send('hi',{kind='BN_WHISPER',target=44}) and target==44)
        C_Club={GetStreamInfo=function() return {} end,SendMessage=function(c,s,t) target=c..':'..s end}
        assert(gg.Main.Send('hi',{kind='COMMUNITIES_CHANNEL',club=1,stream=2}) and target=='1:2')''')
    def test_custom_long_utf8(self):
        self.check('''local b=gg.GratzButton
        gg.Core.db.settings.autoMessage=string.rep('é',200)..' {name}'
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        b.Press(); assert(#mockChat[1].text<=255 and mockChat[1].text==gg.Core.UTF8Cut(gg.Core.ChatText(gg.Core.db.settings.autoMessage),255))''')
    def test_personal_level_resets_reward(self):
        self.check('''mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1); gg.GratzButton.Press()
        local id=gg.Main.guild.celebration.id
        gg.Main.LevelUp(41)
        assert(gg.Main.guild.celebration.id~=id and gg.Main.guild.celebration.source=='levelUp')
        assert(gg.Core.CanCredit(gg.Main.guild,time()))''')
    def test_partial_send_and_unchanged_deadline(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockIncoming(gg,'CHAT_MSG_WHISPER','ding','Jaina',2)
        C_ChatInfo.SendChatMessage=function(text,kind) if kind=='WHISPER' then error('failed') end end
        b.Press()
        assert(#b.entries==1 and b.entries[1].key=='jaina-testrealm' and b.remaining==40)
        assert(gg.Main.guild.celebration.source=='gratzButton')
        b.Combat(true); mockAdvance(gg,300)
        assert(gg.Celebrations.Remaining(gg.Main.guild)==0 and b.remaining==40)''')
    def test_participation_reload_and_migration(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1); b.Press()
        mockIncoming(gg,'CHAT_MSG_GUILD','gratz','Jaina',2)
        local g=gg.Main.guild; local deadline=g.celebration.expiresAt
        mockAdvance(gg,20); gg.Main.Initialize()
        assert(g.celebration.count==1 and g.celebration.expiresAt==deadline)
        assert(not g.replyWindow)
        gg.Core.GetGuild(g.name,g.realm); assert(not g.replyWindow)
        assert(gg.Celebrations.Remaining(g)==280)''')
    def test_drag_disable_and_reduced_motion(self):
        self.check('''local b=gg.GratzButton
        b.Preview(); b.frame.scripts.OnDragStart(b.frame)
        b.frame.scripts.OnClick(); assert(not b.pressed)
        b.frame.scripts.OnDragStop(b.frame); assert(gg.Core.db.settings.gratzPosition)
        gg.Core.db.settings.reducedMotion=true
        b.Press(); b.Update()
        assert(#mockChat==0 and #mockSounds==1 and b.base:GetWidth()==210)
        mockAdvance(gg,1); b.Clear()
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        gg.Core.db.settings.autoEnabled=false; b.Update()
        assert(#b.entries==0 and not b.frame:IsShown())''')
    def test_custom_message_is_literal(self):
        self.check('''gg.Core.db.settings.autoMessage='Well done! {name} {level}'
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Jaina',2)
        gg.GratzButton.Press()
        assert(#mockChat==1 and mockChat[1].text=='Well done! {name} {level}')''')
    def test_close_skips_batch_and_allows_new_dings(self):
        self.check('''local b=gg.GratzButton
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockClick(b.close); mockAdvance(gg,1)
        assert(#mockChat==0 and #mockSounds==0 and not gg.Main.guild.celebration)
        assert(#b.entries==0 and not b.remaining and not b.frame:IsShown())
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Jaina',2)
        assert(#b.entries==1 and b.frame:IsShown() and b.remaining==30)
        b.Press(); assert(#mockChat==1 and mockChat[1].text=='Gratz!')''')
    def test_close_preview_and_animation(self):
        self.check('''local b=gg.GratzButton
        b.Preview(); b.Press(); mockClick(b.close); mockAdvance(gg,1)
        assert(not b.preview and not b.pressed and not b.frame:IsShown())
        assert(#mockChat==0 and #mockSounds==0 and not gg.Main.guild.celebration)
        assert(b.base:GetWidth()==210 and b.flash.alpha==0)''')
    def test_close_preserves_existing_rewards(self):
        self.check('''gg.Main.LevelUp(41)
        local s=gg.Main.guild.celebration; local deadline=s.expiresAt
        mockIncoming(gg,'CHAT_MSG_GUILD','ding','Thrall',1)
        mockClick(gg.GratzButton.close)
        assert(gg.Main.guild.celebration==s and s.expiresAt==deadline and s.count==0)
        assert(#mockChat==1)''')
if __name__=='__main__': unittest.main()
