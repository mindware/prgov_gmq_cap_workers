# Adding simple colorization to our outputs 
class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end
  def black
    colorize(30)
  end
  def red
    colorize(31)
  end
  def green
    colorize(32)
  end
  def brown
    colorize(33)
  end
  alias :yellow :brown
  def blue
    colorize(34)
  end
  def magenta
    colorize(35)
  end
  def cyan
    colorize(36)
  end
  def gray
    colorize(37)
  end
  def bg_black
    colorize(40)
  end
  def bg_red
    colorize(41)
  end
  def bg_green
    colorize(42)
  end
  def bg_brown
    colorize(43)
  end
  def bg_blue
    colorize(44)
  end
  def bg_magenta
    colorize(45)
  end
  def bg_cyan
    colorize(46)
  end
  def bg_gray
    colorize(47)
  end
  def bold
    "\033[1m#{self}\033[22m" 
  end
  def reverse_color 
     "\033[7m#{self}\033[27m" 
  end

  def no_colors
    self.gsub /\033\[\d+m/, ""
  end
end
