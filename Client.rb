require 'socket'

 Shoes.app do
	@el_address = edit_line "127.0.0.1:5668"
		@el_address.style :width=>512
	@btn_connect = button "Connect"
	@eb_dialog = edit_box
		@eb_dialog.style :width=>600, :height=>400
	@el_msg = edit_line
		@el_msg.style :width=>600
	
		
	
	@el_msg.finish = proc { 
		@eb_dialog.text = @eb_dialog.text + @el_msg.text + "\n"
		@el_msg.text = ""
	}
 end