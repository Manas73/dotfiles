--------------------
-- WINDOW LAYOUTS --
--------------------

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/

hl.config({
  dwindle = {
    preserve_split = true, -- You probably want this
    force_split    = 2,
  },

  master = {
    new_status = "slave",
  },
})
