local attachment = {
    attached_bone = "gun",

}
function attachment:construct()
    if self.instance then
        assert(self.gun, "attachment has no gun")
    end
end
function attachment:update_entity()
    self.entity =
end
Guns4d.gun_attachment = mtul.class.new_class:inherit(attachment)