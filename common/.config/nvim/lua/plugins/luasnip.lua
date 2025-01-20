return {
	{
		'L3MON4D3/LuaSnip',
		config = function()
			local ls = require("luasnip")
			local types = require('luasnip.util.types')
			local util = require("luasnip.util.util")
			local node_util = require("luasnip.nodes.util")
			local t = ls.text_node
			local s = ls.snippet

			vim.keymap.set({'i', 's'}, '<M-k>', function()
			if ls.expand_or_jumpable() then
				ls.expand_or_jump()
			end
			end, { silent = true })
			vim.keymap.set({'i', 's'}, '<M-j>', function()
			if ls.jumpable(-1) then
				ls.jump(-1)
			end
			end, { silent = true })
			vim.keymap.set({'i', 's'}, '<M-l>', function()
			if ls.choice_active() then
				ls.change_choice(1)
			end
			end, { silent = true })
			vim.keymap.set({'i', 's'}, '<C-M-j>', '<cmd>lua _G.dynamic_node_external_update(1)<CR>', { noremap = true })
			vim.keymap.set({'i', 's'}, '<C-M-k>', '<cmd>lua _G.dynamic_node_external_update(2)<CR>', { noremap = true })

			ls.config.setup({
			store_selection_keys = '<M-h>',
			history = true,
			updateevents = "TextChanged,TextChangedI",
			enable_autosnippets = true,
			ext_opts = {
				[types.choiceNode] = {
					active = {
						virt_text = { { "●", "GruvboxOrange" } },
						priority = 0,
					},
				},
			},
			})

			require("luasnip.loaders.from_lua").load({paths="./lua/luasnippets"})


			-- Needed for <C-M-j> / <C-M-k> keybinds
			local function find_dynamic_node(node)
				while not node.dynamicNode do
					node = node.parent
				end
				return node.dynamicNode
			end

			-- Needed for <C-M-j> / <C-M-k> keybinds
			local external_update_id = 0
			function dynamic_node_external_update(func_indx)
				-- most of this function is about restoring the cursor to the correct
				-- position+mode, the important part are the few lines from
				-- `dynamic_node.snip:store()`.


				-- find current node and the innermost dynamicNode it is inside.
				local current_node = ls.session.current_nodes[vim.api.nvim_get_current_buf()]

				-- If there is an error, return. This will prevent errors from displaying
				-- when calling this function while outside of a dynamic node or snippet.
				local success, dynamic_node = pcall(find_dynamic_node, current_node)
				if not success then
					return
				end

				-- to identify current node in new snippet, if it is available.
				external_update_id = external_update_id + 1
				current_node.external_update_id = external_update_id

				-- store which mode we're in to restore later.
				local insert_pre_call = vim.fn.mode() == "i"
				-- is byte-indexed! Doesn't matter here, but important to be aware of.
				local cursor_pos_pre_relative = util.pos_sub(
					util.get_cursor_0ind(),
					current_node.mark:pos_begin_raw()
				)

				-- leave current generated snippet.
				node_util.leave_nodes_between(dynamic_node.snip, current_node)

				-- call update-function.
				local func = dynamic_node.user_args[func_indx]
				if func then
					-- the same snippet passed to the dynamicNode-function. Any output from func
					-- should be stored in it under some unused key.
					func(dynamic_node.parent.snippet)
				end

				-- last_args is used to store the last args that were used to generate the
				-- snippet. If this function is called, these will most probably not have
				-- changed, so they are set to nil, which will force an update.
				dynamic_node.last_args = nil
				dynamic_node:update()

				-- everything below here isn't strictly necessary, but it's pretty nice to have.

				-- try to find the node we marked earlier.
				local target_node = dynamic_node:find_node(function(test_node)
					return test_node.external_update_id == external_update_id
				end)

				if target_node then
					-- the node that the cursor was in when changeChoice was called exists
					-- in the active choice! Enter it and all nodes between it and this choiceNode,
					-- then set the cursor.
					node_util.enter_nodes_between(dynamic_node, target_node)

					if insert_pre_call then
						util.set_cursor_0ind(
							util.pos_add(
								target_node.mark:pos_begin_raw(),
								cursor_pos_pre_relative
							)
						)
					else
						node_util.select_node(target_node)
					end
					-- set the new current node correctly.
					ls.session.current_nodes[vim.api.nvim_get_current_buf()] = target_node
				else
					-- the marked node wasn't found, just jump into the new snippet noremally.
					ls.session.current_nodes[vim.api.nvim_get_current_buf()] = dynamic_node.snip:jump_into(1)
				end
			end
		end
	},
}
