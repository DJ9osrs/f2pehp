require 'open-uri'
class Player < ActiveRecord::Base
  
  SKILLS = ["attack", "strength", "defence", "hitpoints", "ranged", "prayer",
            "magic", "cooking", "woodcutting", "fishing", "firemaking", "crafting",
            "smithing", "mining", "runecraft", "overall"]
  
  TIMES = ["day", "week", "month", "year"]
  
  SUPPORTERS = ["Bargan",
                "Freckled Kid",
                "Obor",
                "Gl4Head",
                "Ikiji",
                "Xan So",
                "Netbook Pro",
                "F2P Lukie",
                "Tame My Wild",
                "FitMC",
                "Pink skirt",
                "UIM STK F2P",
                "MA5ON",
                "For Ulven",
                "tannerdino",
                "Playing Fe",
                "Pawz",
                "Yellow bead",
                "ZINJAN",
                "Valleyman6",
                "Snooz Button",
                "IronMace Din",
                "HCIM_btw_fev",
                "citnA",
                "Lea Sinclair",
                "lRAIDERSS",
                "Sofacanlazy",
                "I love rs",
                "Say F2p Ult",
                "Irish Woof",
                "Faij",
                "Leftoverover",
                "DJ9",
                "Drae",
                "David BBQ",
                "Schwifty Bud",
                "UI Pain",
                "Fe F2P",
                "WishengradHC",
                "n4ckerd",
                "Tohno1612",
                "H C Gilrix",
                "Frogmask",
                "NoQuestsHCIM",
                "Adentia",
                "threewaygang",
                "5perm sock",
                "Sir BoJo",
                "f2p Ello",
                "Ghost Bloke",
                "Fe Apes",
                "Iron of One",
                "InsurgentF2P",
                "cwismis noob",
                "Sad Jesus",
                "SapphireHam",
                "Doublessssss",
                "ColdFingers1",
                "xmymwf609",
                "Cas F2P HC",
                "Onnn",
                "Shade_Core",
                "Metan",
                "F2P UIM OREO",
                "Crawler",
                "UIM Dakota",
                "HCBown",
                "Dukeddd",
                "one a time",
                "Yewsless",
                "Wizards Foot",
                "F2P Jords",
                "a q p IM"]
  
  def self.supporters()
    SUPPORTERS
  end
  
  def self.sql_supporters()
    quoted_names = SUPPORTERS.map{ |name| "'#{name}'" }
    "(#{quoted_names.join(",")})"
  end
  
  # The characters +, _, \s, -, %20 count as the same when doing a lookup on hiscores.
  def self.sanitize_name(str)
    if str.downcase == "_yrak"
      return str
    else
      str = str.gsub(/[-_\\+]|(%20)/, " ")
      return str.gsub(/\A[^A-z0-9]+|[^A-z0-9\s\_-]+|[^A-z0-9]+\z/, "")
    end
  end
  
  def self.find_player(id)
    id = self.sanitize_name(id)
    player = Player.where('lower(player_name) = ?', id.downcase).first
    if player.nil?
      name = id.gsub("_", " ")
      player = Player.where('lower(player_name) = ?', name.downcase).first
    end
    if player.nil?
      name = id.gsub(" ", "_")
      player = Player.where('lower(player_name) = ?', name.downcase).first
    end
    if player.nil?
      begin
        player = Player.find(Float(id))
      rescue
        return false
      end
    end
    return player
  end
  
  def get_stats
    name = player_name
    if name == "Bargan"
      all_stats = "-1,1410,143408971 -1,99,13078967 -1,99,13068172 -1,99,13069431 -1,99,14171944 -1,85,3338143 -1,82,2458698 -1,99,13065371 -1,99,14018193 -1,91,6111148 -1,-1,0 -1,92,6557350 -1,99,14021572 -1,99,13074360 -1,99,13182234 -1,81,2195415 -1,-1,0 -1,-1,0 -1,-1,0 -1,-1,0 -1,-1,0 -1,80,1997973 -1,-1,0 -1,-1,0 -1,-1 -1,-1 -1,-1 -1,-1 -1,-1 -1,-1 -1,-1 -1,-1 -1,-1".split(" ")
    else
      begin
        case player_acc_type
        when "Reg"
          uri = URI.parse("https://services.runescape.com/m=hiscore_oldschool/index_lite.ws?player=#{name}")
        when "HCIM"
          uri = URI.parse("https://services.runescape.com/m=hiscore_oldschool_hardcore_ironman/index_lite.ws?player=#{name}")
        when "UIM"
          uri = URI.parse("https://services.runescape.com/m=hiscore_oldschool_ultimate/index_lite.ws?player=#{name}")
        when "IM"
          uri = URI.parse("https://services.runescape.com/m=hiscore_oldschool_ironman/index_lite.ws?player=#{name}")
        end
        all_stats = uri.read.split(" ")
      rescue Exception => e  
        puts e.message 
        return false
      end
    end
    return all_stats
  end
  
  def check_hc_death
    if player_acc_type == "HCIM"
      begin
        im_uri = URI.parse("https://services.runescape.com/m=hiscore_oldschool_ironman/index_lite.ws?player=#{self.player_name}")
        im_stats = im_uri.read.split(" ")
        im_xp = im_stats[0].split(",")[2].to_f
        hc_uri = URI.parse("https://services.runescape.com/m=hiscore_oldschool_hardcore_ironman/index_lite.ws?player=#{self.player_name}")
        hc_stats = hc_uri.read.split(" ")
        hc_xp = hc_stats[0].split(",")[2].to_f
        if hc_xp < (im_xp - 1000000)
          update_attribute(:player_acc_type, "IM")
        end
      rescue Exception => e   
        puts e.message 
      end
    end
  end
  
  def calc_ehp
    ehp = get_ehp_type
    all_stats = get_stats
    update_attribute(:potential_p2p, "0")
    total_ehp = 0.0
    total_lvl = 8
    total_xp = 0
    under_34 = false
    bonus_xp = calc_bonus_xp(all_stats)
    F2POSRSRanks::Application.config.skills.each.with_index do |skill, skill_idx|
      skill_lvl = all_stats[skill_idx].split(",")[1].to_f
      skill_xp = all_stats[skill_idx].split(",")[2].to_f
      skill_rank = all_stats[skill_idx].split(",")[0].to_f
      
      if skill == "hitpoints" and skill_lvl < 10
        skill_lvl = 10
        skill_xp = 1154
      end
      if skill != "p2p" and skill != "overall" and skill != "lms" and skill != "p2p_minigame"
        if skill_xp < 0
          update_attribute(:"#{skill}_xp", 0)
        else
          update_attribute(:"#{skill}_xp", skill_xp)
        end
      
        if bonus_xp[skill]
          skill_xp -= bonus_xp[skill]
        end
        
        skill_ehp = 0.0
        skill_tiers = ehp["#{skill}_tiers"]
        skill_xphrs = ehp["#{skill}_xphrs"]
        skill_tiers.each.with_index do |skill_tier, tier_idx|
          skill_tier = skill_tier.to_f
          skill_xphr = skill_xphrs[tier_idx].to_f
          if skill_xphr != 0 and skill_tier < skill_xp
            if (tier_idx + 1) < skill_tiers.length and skill_xp >=  skill_tiers[tier_idx + 1]
              skill_ehp += (skill_tiers[tier_idx+1].to_f - skill_tier)/skill_xphr
            else
              skill_ehp += (skill_xp.to_f - skill_tier)/skill_xphr
            end
          end
        end
        update_attribute(:"#{skill}_lvl", skill_lvl)
        update_attribute(:"#{skill}_ehp", skill_ehp.round(2))
        update_attribute(:"#{skill}_rank", skill_rank)
        total_ehp += skill_ehp.round(2)
        total_xp += skill_xp
        total_lvl += skill_lvl
      elsif skill == "p2p" and skill_xp > 0 
        update_attribute(:potential_p2p, skill_xp)
        Player.where(player_name: player_name).destroy_all
      elsif skill == "p2p_minigame" and skill_lvl > 0
        update_attribute(:potential_p2p, skill_lvl)
        Player.where(player_name: player_name).destroy_all
      elsif skill == "overall"
        if skill_lvl < 34
          under_34 = true
        else
          update_attribute(:"#{skill}_lvl", skill_lvl)
          update_attribute(:"#{skill}_xp", skill_xp)
          update_attribute(:"#{skill}_rank", skill_rank)
        end
      end
    end
    
    update_attribute(:overall_ehp, total_ehp.round(2))
    
    if under_34
      update_attribute(:"overall_lvl", total_lvl)
      update_attribute(:"overall_xp", total_xp)
    end
      
    if potential_p2p.to_f <= 0
      update_attribute(:potential_p2p, "0")
    else
      Player.where(player_name: player_name).destroy_all
    end
  end
  
  def check_p2p
    if potential_p2p.to_f > 0
      destroy
      return true
    end
    return false
  end

  def calc_combat
    att = attack_lvl
    str = strength_lvl
    defence = defence_lvl
    hp = hitpoints_lvl
    ranged = ranged_lvl
    magic = magic_lvl
    pray = prayer_lvl
    
    base = 0.25 * (defence + hp + (pray/2).floor)
    melee = 0.325 * (att + str)
	  range = 0.325 * ((ranged/2).floor + ranged)
	  mage = 0.325 * ((magic/2).floor + magic)
    combat = (base + [melee, range, mage].max).round(5)
    
    if combat < 3.4
      combat = 3.4
    end
    
    update_attribute(:combat_lvl, combat)
  end

  def get_ehp_type
    case player_acc_type
    when "Reg"
      ehp = F2POSRSRanks::Application.config.ehp_reg
    when "HCIM", "IM"
      ehp = F2POSRSRanks::Application.config.ehp_iron
    when "UIM"
      ehp = F2POSRSRanks::Application.config.ehp_uim
    end
  end
  
  def remove_cutoff
    if overall_ehp < 1
      Player.where(player_name: player_name).destroy_all
      return true
    end
  end
  
  def update_player
    if F2POSRSRanks::Application.config.downcase_fakes.include?(player_name.downcase)
      Player.where(player_name: player_name).destroy_all
    end
    puts player_name
    all_stats = get_stats
    if all_stats == false
      Player.where(player_name: player_name).destroy_all
      return false
    end
    calc_ehp
    if check_p2p
      Player.where(player_name: player_name).destroy_all
      return "p2p"
    end
    check_hc_death
    calc_combat
    if remove_cutoff
      return "cutoff"
    end
    
    # if overall_ehp > 250 or Player.supporters.include?(player_name)
    #   TIMES.each do |time|
    #     xp = self.read_attribute("overall_xp_#{time}_start")
    #     if xp.nil? or xp == 0
    #       update_player_start_stats(time)
    #     end
    #   end
      
    #   check_record_gains
    # end
    
    # update_attributes(:ttm_lvl => time_to_max("lvl"), :ttm_xp => time_to_max("xp"))
  end
  
  def check_record_gains
    SKILLS.each do |skill|
      xp = self.read_attribute("#{skill}_xp")
      ehp = self.read_attribute("#{skill}_ehp")
      TIMES.each do |time|
        start_xp = self.read_attribute("#{skill}_xp_#{time}_start")
        start_ehp = self.read_attribute("#{skill}_ehp_#{time}_start")
        max_xp = self.read_attribute("#{skill}_xp_#{time}_max")
        max_ehp = self.read_attribute("#{skill}_ehp_#{time}_max")
        if start_xp.nil? or start_ehp.nil?
          next
        end
        if max_xp.nil? or xp - start_xp > max_xp
          update_attributes("#{skill}_xp_#{time}_max" => xp - start_xp)
        end
        if max_ehp.nil? or ehp - start_ehp > max_ehp
          update_attributes("#{skill}_ehp_#{time}_max" => ehp - start_ehp)
        end
      end
    end
  end
  
  def update_player_start_stats(time)
    SKILLS.each do |skill|
      xp = self.read_attribute("#{skill}_xp")
      ehp = self.read_attribute("#{skill}_ehp")
      update_attributes("#{skill}_xp_#{time}_start" => xp)
      update_attributes("#{skill}_ehp_#{time}_start" => ehp)
    end
  end
  
  def calc_skill_ehp(xp, tiers, xphrs)
    ehp = 0
    tiers.each.with_index do |tier, idx|
      tier = tier.to_f
      xphr = xphrs[idx].to_f
      if xphr != 0 and tier < xp
        if (idx+1) < tiers.length and xp >=  tiers[idx+1]
          ehp += (tiers[idx+1].to_f - tier)/xphr
        else
          ehp += (xp.to_f - tier)/xphr
        end
      end
    end
    return ehp
  end
  
  def calc_max_lvl_ehp(tiers, xphrs)
    return calc_skill_ehp(13034431, tiers, xphrs)
  end
  
  def calc_max_xp_ehp(tiers, xphrs)
    return calc_skill_ehp(200000000, tiers, xphrs)
  end
  
  def time_to_max(lvl_or_xp)
    ehp = get_ehp_type
    time_to_max = 0
    F2POSRSRanks::Application.config.skills.each do |skill|
      if skill != "p2p" and skill != "overall" and skill != "lms" and skill != "p2p_minigame"
        skill_ehp = self.read_attribute("#{skill}_ehp")
        if lvl_or_xp == "lvl"
          max_ehp = calc_max_lvl_ehp(ehp["#{skill}_tiers"], ehp["#{skill}_xphrs"])
        else
          max_ehp = calc_max_xp_ehp(ehp["#{skill}_tiers"], ehp["#{skill}_xphrs"])
        end
        
        max_ehp = (max_ehp*100).floor/100.0

        if max_ehp > skill_ehp
          time_to_max += max_ehp - skill_ehp
        end
      end
    end
    return time_to_max
  end
  
  def get_bonus_xp
    case player_acc_type
    when "Reg"
      bonus_xp = F2POSRSRanks::Application.config.bonus_xp_reg
    when "HCIM", "IM"
      bonus_xp = F2POSRSRanks::Application.config.bonus_xp_iron
    when "UIM"
      bonus_xp = F2POSRSRanks::Application.config.bonus_xp_uim
    end
    return bonus_xp
  end
  
  def calc_bonus_xp(all_stats)
    bonus_xps = get_bonus_xp
    bonuses = {}
    skills_list = F2POSRSRanks::Application.config.skills
    bonus_xps.each do |ratio, bonus_for, bonus_from, start_xp, end_xp|
      skill_from = all_stats[skills_list.index(bonus_from)].split(",")[2].to_i     
      if skill_from <= start_xp.to_i
        next
      end
      
      bonus_xp = ([skill_from, end_xp].min - start_xp.to_i)*ratio.to_f
      
      if bonuses[bonus_for]
        bonuses[bonus_for] += bonus_xp
      else
        bonuses[bonus_for] = bonus_xp
      end
    end
    return bonuses
  end
end
