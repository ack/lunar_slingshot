require 'gosu'
require './floatingObject'
require './player'
require './star'
require './explosion'
require './bullet'
require './moon'



module ZOrder
  Background, Moon, Stars, Player, UI = *0..3
 # Background, Moon, Stars, Player, UI = *0..3
end

class GameWindow < Gosu::Window
  def initialize
    super(640, 480, false)
    self.caption = "Lunar Slingshot"
    @jet_sound = Gosu::Sample.new(self, "media/jet_sound.wav")
    @background_image = Gosu::Image.new(self, "media/Space.png", true)
    @star_anim = Gosu::Image::load_tiles(self, "media/Star.png", 2, 2, false)
    @stars = []
    @stars << (Star.new(@star_anim))
    @font = Gosu::Font.new(self, Gosu::default_font_name, 20)
    @thrusting = [false, false]
    @explosion_image = Explosion.new Gosu::Image::load_tiles(self, "media/explosion.png", 40, 40, false)
    @keyboard_controls_left = [false, false, false, false]
    @keyboard_controls_right = [false, false, false, false]
    @update_count = 0
    @moon = Moon.new(self)
    @players = []
    @bullets = []
    @bullets[0] = nil
    @bullets[1] = nil
    @players[0] = Player.new(self, 1)
    @players[1] = Player.new(self, 2)
    @players[0].warp(100, 240)
    @players[1].warp(540, 240)
    @fire_armed = [true, true]
    @explosion_location_x = 0
    @explosion_location_y = 0
    @explosion_active = false
    @explosion_offset_x = -20
    @explosion_offset_y = -20
    @explosion = Gosu::Sample.new(self, "media/Explosion.wav")
    #@game_song = Gosu::Song.new(self, "media/song.aif")
    #@game_song.play
  end

  def update #changes the state of the variables every iteration
    @update_count += 1
    if @game_over_time != nil
      if Time.now >= @game_over_time + 2 
        @game_over_time = nil
        @bullets = []
        @players[0].score = @players[1].score = 0
        @players[0].warp(100, 240)
        @players[1].warp(540, 240)
        @players[0].reset_velocity
        @players[1].reset_velocity
      else
        @explosion_image.update
      end
    else
      #read the commands left
      @keyboard_controls_left[0] = button_down?(Gosu::KbS)
      @keyboard_controls_left[1] = button_down?(Gosu::KbF)
      @keyboard_controls_left[2] = button_down?(Gosu::KbE)
      @keyboard_controls_left[3] = button_down?(Gosu::KbD)

      #read the commands right
      @keyboard_controls_right[0] = button_down?(Gosu::KbJ)
      @keyboard_controls_right[1] = button_down?(Gosu::KbL)
      @keyboard_controls_right[2] = button_down?(Gosu::KbI)
      @keyboard_controls_right[3] = button_down?(Gosu::KbK)

      # now perform move and draw for each player
      2.times do |player_index|
        if player_index == 0
          key_commands = @keyboard_controls_left
        else
          key_commands = @keyboard_controls_right
        end

        # use the commands
        @players[player_index].turn_left(key_commands[0])
        @players[player_index].turn_right(key_commands[1])

       
        #process fire button
        if key_commands[2] #if button returns true
          if @fire_armed[player_index] #if armed
            #fire
            new_bullet = @players[player_index].fire
            if new_bullet != nil
              new_bullet.expiration = @update_count + 200
              @bullets << new_bullet
            end
            
            @fire_armed[player_index] = false #disarm
          else #not armed
            #nothing
          end
        else # button returns false
          if @fire_armed[player_index] #if armed
            #nothing
          else #not armed
            #arm it
            @fire_armed[player_index] = true
         end
        end 

        if key_commands[3] == true
          @players[player_index].accelerate
          @thrusting[player_index] = true
          start_jet_sound(player_index + 1)
        else
          @thrusting[player_index] = false
          stop_jet_sound(player_index + 1)
        end      

        # move player and collect stars
        @players[player_index].move
        @players[player_index].collect_stars(@stars)

        # checks for player touching moon
        if @players[player_index].touches?(@moon)
          stop_jet_sound(1)
          stop_jet_sound(2)     
          @players[0].die
          @players[1].die
          set_explosion(@players[player_index].x, @players[player_index].y)
        end

        # check for player touching bullets
        # iterate over array of bullets 
        @bullets.each do |bullet|
          if bullet != nil && @players[player_index].touches?(bullet) 
            stop_jet_sound(1)
            stop_jet_sound(2)     
            @players[0].die
            @players[1].die
            set_explosion(@players[player_index].x, @players[player_index].y)
          end
        end
      end  #end of player index loop
      # check for player touching player
      if @players[0].touches?(@players[1])
        stop_jet_sound(1)
        stop_jet_sound(2)     
        @players[0].die
        @players[1].die
        set_explosion(@players[0].x, @players[0].y)
      end

      #check bullets touching other bullets or moon
      max_index = @bullets.length

      @bullets.length.times do 
        bullet = @bullets.shift
        if bullet != nil 
          bullet.move
          if @update_count >= bullet.expiration
            bullet = nil
          end
        end
        if bullet != nil
          @bullets.push(bullet)
        end
      end
    

      # move the bullets for players
      

      bulletA_index = 0
      max_index.times do
        # check bullet A against the moon


        if @bullets[bulletA_index] != nil && @bullets[bulletA_index].touches?(@moon)
          @bullets[bulletA_index].die
          @bullets[bulletA_index] = nil
          break
        end
        bulletB_index = bulletA_index + 1

        # check bullet A agains bullet B
        (max_index - bulletB_index).times do
          
          # bulletsB_index might be nil 
          if @bullets[bulletA_index] != nil && @bullets[bulletA_index].touches?(@bullets[bulletB_index])
            @bullets[bulletA_index].die
            @bullets[bulletB_index].die
            @bullets[bulletA_index] = nil
            @bullets[bulletB_index] = nil
          end
          bulletB_index += 1
        end
        bulletA_index += 1 
      end

      # make new stars
      if rand(100) < 4 and @stars.size < 25 then
        @stars.push(Star.new(@star_anim))
      end
    end
  end

  def draw #draws the varibales everytime it its called 
    @background_image.draw(0, 0, ZOrder::Background)
    @moon.draw(false, 3)
    @stars.each { |star| star.draw }
    @font.draw("Red: #{@players[0].score}", 10, 10, ZOrder::Player, 1.0, 1.0, 0xffffff00)
    @font.draw_rel("Blue: #{@players[1].score}", 630, 10, ZOrder::Player, 1.0, 0, 1.0, 1.0, 0xffffff00)
    @font.draw_rel("Frame: #{@update_count}", 330, 10, ZOrder::Player, 1.0, 0, 1.0, 1.0, 0xffffff00)
    #calculate FPS using time!!
    
    @bullets.each do |bullet|
      if bullet != nil
        bullet.draw(false, 3)
      end
    end

    # if @game_over_time == nil
    @players[0].draw(@thrusting[0], 1)
    @players[1].draw(@thrusting[1], 2)      
    # end

    if @game_over_time != nil
      @explosion_image.draw(@explosion_location_x + @explosion_offset_x, @explosion_location_y + @explosion_offset_y)
      @font.draw("GAME OVER", 258, 140, ZOrder::Player,1.0, 1.0, 0xffffffff)
    end
  end

  def set_explosion(location_x, location_y)
    @explosion.play
    @explosion_location_x = location_x
    @explosion_location_y = location_y
    @game_over_time = Time.now
  end

  # def clear_explosion

  # end

  def button_down(id)
    if id == Gosu::KbEscape
      close
    end
  end

  def stop_jet_sound(player)
    if player == 1
      if @jet_sound_instance != nil
        @jet_sound_instance.stop
        @jet_sound_instance = nil
      end
    end
    if player == 2
      if @jet_sound_instance_p2 != nil
        @jet_sound_instance_p2.stop
        @jet_sound_instance_p2 = nil
      end
    end
  end

   def start_jet_sound(player)
    if player == 1
      if @jet_sound_instance == nil
        @jet_sound_instance = @jet_sound.play(1, 1, true) #volume, speed, looping
      end
    end
    if player == 2
      if @jet_sound_instance_p2 == nil
        @jet_sound_instance_p2 = @jet_sound.play(1, 1, true) #volume, speed, looping
      end
    end
  end
end

window = GameWindow.new
window.show