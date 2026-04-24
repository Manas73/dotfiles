# Kill focused window
super + q
    i3-msg kill

# Change focus
super + {j,k,l,semicolon}
    i3-msg focus {left,down,up,right}

# Alternative focus with cursor keys
super + {Left,Down,Up,Right}
    i3-msg focus {left,down,up,right}

# Move focused window
super + shift + {j,k,l,semicolon}
    i3-msg move {left,down,up,right}

# Alternative move with cursor keys
super + shift + {Left,Down,Up,Right}
    i3-msg move {left,down,up,right}

# Split in vertical orientation
super + v
    i3-msg split v

# Enter fullscreen mode for the focused container
super + f
    i3-msg fullscreen toggle

# Change container layout
super + s
    i3-msg layout stacking

super + w
    i3-msg layout tabbed

super + e
    i3-msg layout toggle split

# Toggle tiling / floating
super + shift + space
    i3-msg floating toggle

# Switch to workspace
super + {1,2,3,4,5}
    i3-msg workspace {"1:General", "2:IDE", "3:Dev", "4:Slack", "5:Rambox"}

alt + {1,2,3,4,5}
    i3-msg workspace {"6:Timepass", "7:Zoom", "8:Extra", "9:Extra", "10:Extra"}

# Move focused container to workspace
super + shift + {1,2,3,4,5}
    i3-msg move container to workspace {"1:General", "2:IDE", "3:Dev", "4:Slack", "5:Rambox"}

alt + shift + {1,2,3,4,5}
    i3-msg move container to workspace {"6:Timepass", "7:Zoom", "8:Extra", "9:Extra", "10:Extra"}

# Restart i3 inplace
super + shift + r
    i3-msg restart

# Resize mode - resize till you hit Esc
super + r: {j,k,l,semicolon}
    i3-msg resize {shrink width,shrink height,grow height,grow width} 10 px or 10 ppt

super + r: {Left,Down,Up,Right}
    i3-msg resize {shrink width,shrink height,grow height,grow width} 10 px or 10 ppt
