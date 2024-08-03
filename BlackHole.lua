--- STEAMODDED HEADER
--- MOD_NAME: Black Hole
--- MOD_ID: BlackHole
--- PREFIX: blh
--- MOD_AUTHOR: [Aure]
--- MOD_DESCRIPTION: Screen reader mod for Balatro.
--- VERSION: 0.1.0

BlackHole = SMODS.current_mod
tts = SMODS.load_file('Love2talk/Love2talk.lua')()
G.E_MANAGER:add_event(Event{
    func = function()
        if SMODS.booted then
            tts.say(localize { type = 'variable', key = 'tts_welcome', vars = { BlackHole.version } })
            return true
        end
    end
})
SMODS.Keybind{
	key = 'welcome',
	key_pressed = '1',
    action = function(controller)
        tts.silence()
        tts.say(localize { type = 'variable', key = 'tts_welcome', vars = { BlackHole.version }})
    end,
}
SMODS.Keybind{
	key = 'game_speed',
	key_pressed = '2',
    action = function(controller)
        local nopeus = (SMODS.Mods.nopeus or {}).can_load
        local sequence = {
            [0.25] = 0.5,
            [0.5] = 1,
            [1] = 2,
            [2] = nopeus and 3 or 4,
            [3] = 4,
            [4] = nopeus and 8 or 0.5,
            [8] = 16,
            [16] = 32,
            [32] = 64,
            [64] = 999,
            [999] = 0.25,
        }
        G.SETTINGS.GAMESPEED = sequence[G.SETTINGS.GAMESPEED]
        tts.silence()
        tts.say(localize { type = 'variable', key = 'tts_game_speed', vars = { G.SETTINGS.GAMESPEED }})
        G:save_settings()
    end,
}

function BlackHole.process_hover(controller)
    local node = controller.hovering.target
    if BlackHole.hover_suppressed then return end
    -- Do not restart speech  when the same node is hovered again
    if BlackHole.last_tts_node == node and BlackHole.hover_time_elapsed <= 3 then return end
    if node:is(Card) and node.area == G.deck then
         --ugly
            node.tts = localize('k_view')..' '..localize('k_deck')
    end
    if node.tts and node.tts ~= '' then
        tts.silence() 
        if node.area ~= G.deck and node.facing == 'back' then 
            node.tts = node.highlighted and localize({
                    type = 'variable',
                    key = 'tts_highlighted',
                    vars = localize('tts_face_down_card')
                }) or
                localize('tts_face_down_card')
        end
        tts.say(node.tts)
        BlackHole.last_tts_node = node 
        BlackHole.hover_time_elapsed = 0
    else
        BlackHole.read_button(node)
        if node.config.h_popup then BlackHole.read_h_popup(node.config.h_popup, node) end
    end
end

function BlackHole.read_h_popup(popup, node)
    local popup_text = ''
    local function find_strings(target)
        for _, v in ipairs(target.nodes or {}) do
            local text_to_merge = nil
            if v.config and type(v.config.text) == 'string' then
                text_to_merge = ""..v.config.text
            elseif v.config and v.config.object and v.config.object.string then
                text_to_merge = ""..v.config.object.string
            end
            if text_to_merge then
                if text_to_merge:match('^%$+%+?$') then
                    local has_plus = text_to_merge:match('%+$')
                    text_to_merge = localize('$')..(text_to_merge:len() - (has_plus and 1 or 0))..(has_plus and ' +' or '')
                end 
                --TODO this is not always what we want, compare blind reward vs. foil tooltip
                if string.find(text_to_merge, '[%d%+]$') then text_to_merge = text_to_merge..' -' end
                popup_text = popup_text..text_to_merge..' '
            else
                find_strings(v)
            end
        end
    end
    find_strings(popup)
    if popup_text ~= '' then 
        --tts.silence()
        tts.say(popup_text)
        BlackHole.last_tts_node = node
    end
end

function BlackHole.read_button(node)
    local q
    local but_text = ''
    -- Should we just make this a generic function? It's used quite often for reading UI nodes
    -- If we were we'd need to consider an "extra args" function to handle additional text manip such as $ symbol concentration
    local function find_strings(target)
        for _, v in ipairs(target.children or {}) do
            local text_to_merge = nil
            if v.config and type(v.config.text) == 'string' then
                text_to_merge = ""..v.config.text
            elseif v.config and v.config.object and v.config.object.string then
                text_to_merge = ""..v.config.object.string
            end
            if text_to_merge then
                if text_to_merge:match('^%$%$+%+?$') then
                    local has_plus = text_to_merge:match('%+$')
                    text_to_merge = localize('$')..(text_to_merge:len() - (has_plus and 1 or 0))..(has_plus and ' +' or '')
                end
                if string.find(text_to_merge, '%d[%d%+]$') then text_to_merge = text_to_merge..' - ' end
                local x_base = localize('k_x_base')
                if text_to_merge:sub(-#x_base) == x_base then text_to_merge = text_to_merge..' - ' end
                but_text = but_text..text_to_merge..' '
            else
                find_strings(v)
            end
        end
    end
    find_strings(node)
    local is_blind_select_button = false
    for _, v in ipairs{ "Select", "Skipped", "Current", "Defeated", "Upcoming", "Selected" } do
        if but_text == localize(v, 'blind_states')..' ' then is_blind_select_button = true; break end
    end
    if is_blind_select_button then
        but_text = ''
        find_strings(node.parent.parent.parent)
    end
    local is_cashout_button = node.config.id == 'cash_out_button'
    if is_cashout_button then
        but_text = localize {
            type = 'variable',
            key = 'tts_current_money',
            vars = { G.GAME.dollars }
        } .. but_text
        q = true
    end

    local is_tab_shoulders = node.config.id == 'tab_shoulders'
    if is_tab_shoulders then
        but_text = ''
        for _,v in ipairs(node.children) do
            if v.children[1].config.chosen then find_strings(v.children[1]) end
        end
    end
    local is_play_hand = but_text == localize('b_play_hand')..' '
    local is_discard =  but_text == localize('b_discard')..' '
    if is_play_hand or is_discard then
        local amount = G.GAME.current_round[is_play_hand and 'hands_left' or 'discards_left']
        but_text = but_text .. localize {
            type = 'variable',
            key = 'tts_remaining',
            vars = { amount, localize((is_play_hand and 'tts_hand' or 'tts_discard')..(amount ~= 1 and 's' or '')) }
        }
    end
    if is_play_hand and node.config.button then
        if G.boss_throw_hand then
            but_text = but_text.. " - " .. localize('ph_unscored_hand') .. G.GAME.blind:get_loc_debuff_text() .. " - "
        end
        local text,disp_text = G.FUNCS.get_poker_hand_info(G.hand.highlighted)
        local hand = G.GAME.hands[text]
        but_text = but_text .. localize {
            type = 'variable',
            key = 'tts_hand_eval',
            vars = { disp_text, hand.level, hand.chips, hand.mult }
        }
        but_text = but_text .. localize {
            type = 'variable',
            key = 'tts_played_this_run',
            vars = { hand.played, localize('tts_time'..(hand.played ~= 1 and 's' or '')) }
        }
    end
    local is_poker_hand_button = (node.config.on_demand_tooltip and G.GAME.hands[node.config.on_demand_tooltip.filler.args]) and true or nil
    if is_poker_hand_button then
        local poker_hand_info = G.GAME.hands[node.config.on_demand_tooltip.filler.args]
        but_text = localize {
            type = 'variable',
            key = 'tts_hand_eval',
            vars = { localize(node.config.on_demand_tooltip.filler.args, 'poker_hands'), poker_hand_info.level, poker_hand_info.chips, poker_hand_info.mult }
        }
        but_text = but_text .. localize {
            type = 'variable',
            key = 'tts_played_this_run',
            vars = { poker_hand_info.played, localize('tts_time'..(poker_hand_info.played ~= 1 and 's' or '')) }
        }
    end
    if but_text ~= '' then
        if not q then tts.silence() end
        tts.say(but_text)
        BlackHole.last_tts_node = node
    end
end