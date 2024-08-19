return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
			"MunifTanjim/nui.nvim",
			-- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
		},
		opts = {
			filesystem = {
				filtered_items = {
					visible = true,
				},
			},
		},
	},
	-- messages, cmdline and the popupmenu
	{
		"folke/noice.nvim",
		opts = function(_, opts)
			table.insert(opts.routes, {
				filter = {
					event = "notify",
					find = "No information available",
				},
				opts = { skip = true },
			})
			local focused = true
			vim.api.nvim_create_autocmd("FocusGained", {
				callback = function()
					focused = true
				end,
			})
			vim.api.nvim_create_autocmd("FocusLost", {
				callback = function()
					focused = false
				end,
			})
			table.insert(opts.routes, 1, {
				filter = {
					cond = function()
						return not focused
					end,
				},
				view = "notify_send",
				opts = { stop = false },
			})

			opts.commands = {
				all = {
					-- options for the message history that you get with `:Noice`
					view = "split",
					opts = { enter = true, format = "details" },
					filter = {},
				},
			}

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "markdown",
				callback = function(event)
					vim.schedule(function()
						require("noice.text.markdown").keys(event.buf)
					end)
				end,
			})

			opts.presets.lsp_doc_border = true
		end,
	},

	{
		"rcarriga/nvim-notify",
		opts = {
			timeout = 5000,
		},
	},

	-- animations
	{
		"echasnovski/mini.animate",
		event = "VeryLazy",
		opts = function(_, opts)
			opts.scroll = {
				enable = false,
			}
		end,
	},

	-- buffer line
	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		keys = {
			{ "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next tab" },
			{ "<S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev tab" },
		},
		opts = {
			options = {
				mode = "tabs",
				-- separator_style = "slant",
				show_buffer_close_icons = false,
				show_close_icon = false,
			},
		},
	},

	-- statusline
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = {
			options = {
				-- globalstatus = false,
				theme = "solarized_dark",
			},
		},
	},

	-- filename
	{
		"b0o/incline.nvim",
		dependencies = { "craftzdog/solarized-osaka.nvim" },
		event = "BufReadPre",
		priority = 1200,
		config = function()
			local colors = require("solarized-osaka.colors").setup()
			require("incline").setup({
				highlight = {
					groups = {
						InclineNormal = { guibg = colors.magenta500, guifg = colors.base04 },
						InclineNormalNC = { guifg = colors.violet500, guibg = colors.base03 },
					},
				},
				window = { margin = { vertical = 0, horizontal = 1 } },
				hide = {
					cursorline = true,
				},
				render = function(props)
					local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
					if vim.bo[props.buf].modified then
						filename = "[+] " .. filename
					end

					local icon, color = require("nvim-web-devicons").get_icon_color(filename)
					return { { icon, guifg = color }, { " " }, { filename } }
				end,
			})
		end,
	},

	{
		"folke/zen-mode.nvim",
		cmd = "ZenMode",
		opts = {
			plugins = {
				gitsigns = true,
				tmux = true,
				kitty = { enabled = false, font = "+2" },
			},
		},
		keys = { { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" } },
	},

	{
		"nvimdev/dashboard-nvim",
		event = "VimEnter",

		-- Get the graphics from http://patorjk.com/software/taag/#p=display&f=Cheese&t=Gopher-San
		opts = function(_, opts)
			-- local logo = [[
			--       █████   █████  ████████ ███████ ██████       ██████   █████  ██   ██
			--      ██      ██   ██ ██       ██      ██   ██     ██       ██   ██ ███  ██
			--      ██  ███ ██   ██ ██████   ██████  █████   ███  ██████  ██   ██ ██ █ ██
			--      ██   ██ ██   ██ ██       ██      ██  ██            ██ ██ █ ██ ██  ███
			--       █████   █████  ██       ███████ ██   ██      ██████  ██   ██ ██   ██
			--       ]]
			local logo = [[
.d8888b.                    888                            .d8888b.                    
d88P  Y88b                   888                           d88P  Y88b                   
888    888                   888                           Y88b.                        
888         .d88b.  88888b.  88888b.   .d88b.  888d888      "Y888b.    8888b.  88888b.  
888  88888 d88""88b 888 "88b 888 "88b d8P  Y8b 888P"           "Y88b.     "88b 888 "88b 
888    888 888  888 888  888 888  888 88888888 888   888888      "888 .d888888 888  888 
Y88b  d88P Y88..88P 888 d88P 888  888 Y8b.     888         Y88b  d88P 888  888 888  888 
 "Y8888P88  "Y88P"  88888P"  888  888  "Y8888  888          "Y8888P"  "Y888888 888  888 
                    888                                                                 
                    888                                                                 
                    888                                                                 
      ]]
			--      local logo = [[
			--     ,o888888o.        ,o888888o.     8 888888888o   8 8888        8 8 8888888888   8 888888888o.     d888888o.           .8.          b.             8
			--    8888     `88.   . 8888     `88.   8 8888    `88. 8 8888        8 8 8888         8 8888    `88.  .`8888:' `88.        .888.         888o.          8
			-- ,8 8888       `8. ,8 8888       `8b  8 8888     `88 8 8888        8 8 8888         8 8888     `88  8.`8888.   Y8       :88888.        Y88888o.       8
			-- 88 8888           88 8888        `8b 8 8888     ,88 8 8888        8 8 8888         8 8888     ,88  `8.`8888.          . `88888.       .`Y888888o.    8
			-- 88 8888           88 8888         88 8 8888.   ,88' 8 8888        8 8 888888888888 8 8888.   ,88'   `8.`8888.        .8. `88888.      8o. `Y888888o. 8
			-- 88 8888           88 8888         88 8 888888888P'  8 8888        8 8 8888         8 888888888P'     `8.`8888.      .8`8. `88888.     8`Y8o. `Y88888o8
			-- 88 8888   8888888 88 8888        ,8P 8 8888         8 8888888888888 8 8888         8 8888`8b          `8.`8888.    .8' `8. `88888.    8   `Y8o. `Y8888
			-- `8 8888       .8' `8 8888       ,8P  8 8888         8 8888        8 8 8888         8 8888 `8b.    8b   `8.`8888.  .8'   `8. `88888.   8      `Y8o. `Y8
			--    8888     ,88'   ` 8888     ,88'   8 8888         8 8888        8 8 8888         8 8888   `8b.  `8b.  ;8.`8888 .888888888. `88888.  8         `Y8o.`
			--     `8888888P'        `8888888P'     8 8888         8 8888        8 8 888888888888 8 8888     `88. `Y8888P ,88P'.8'       `8. `88888. 8            `Yo
			--      ]]
			logo = string.rep("\n", 8) .. logo .. "\n\n"
			opts.config.header = vim.split(logo, "\n")
		end,
	},
}
