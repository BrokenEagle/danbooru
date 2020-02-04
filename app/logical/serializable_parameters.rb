class SerializableParameters
  def self.serial_parameters(only_string, object)
    only_array = self.split_only_string(only_string)
    self.get_only_hash(only_array, object)
  end

  def self.get_only_hash(only_array, object, seen_objects = [])
    only_hash = {only: [], include: [], methods: []}
    available_includes = object.available_includes
    attributes, methods = object.api_attributes.partition { |attr| object.has_attribute?(attr) }
    # Attributes and/or methods may be included in the final pass, but not includes
    was_seen = seen_objects.include?(object.class.name)
    only_array.each do |item|
      match = item.match(/(\w+)\[(.+?)\]$/)
      item_sym = item.to_sym
      if match && available_includes.include?(match[1].to_sym) && !was_seen
        item_sym = match[1].to_sym
        item_object = object.send(item_sym)
        next if item_object.nil?
        item_object = item_object[0] if item_object.is_a?(ActiveRecord::Relation)
        item_array = self.split_only_string(match[2])
        seen_objects << object.class.name
        item_hash = self.get_only_hash(item_array, item_object, seen_objects)
        only_hash[:include] << Hash[item_sym, item_hash]
      elsif available_includes.include?(item_sym) && !was_seen
        only_hash[:include] << item_sym
      elsif attributes.include?(item_sym)
        only_hash[:only] << item_sym
      elsif methods.include?(item_sym)
        only_hash[:methods] << item_sym
        only_hash[:only] << item_sym
      end
    end
    only_hash.delete(:include) if only_hash[:include].empty?
    only_hash.delete(:methods) if only_hash[:methods].empty?
    only_hash
  end

  def self.split_only_string(only_string)
    only_array = []
    offset = 0
    position = 0
    level = 0
    while true
      str = only_string[Range.new(position, -1)]
      match = str.match(/[,\[\]]/)
      break if !match
      start_pos, end_pos = match.offset(0)
      if match[0] == "," && level == 0
        only_array << only_string[Range.new(offset, position + start_pos - 1)]
        offset = position + end_pos
      elsif match[0] == "["
        level += 1
      elsif match[0] == "]"
        level -= 1
      end
      position += end_pos
    end
    only_array << only_string[Range.new(offset, -1)]
  end

  def self.includes_parameters(only_string, model_name)
    only_array = self.split_only_string(only_string)
    self.get_includes_array(only_array, model_name)
  end

  def self.get_includes_array(only_array, model_name, seen_objects = [])
    include_array = []
    model = eval(model_name)
    available_includes = model.available_includes
    # Attributes and/or methods may be included in the final pass, but not includes
    was_seen = seen_objects.include?(model_name)
    only_array.each do |item|
      match = item.match(/(\w+)\[(.+?)\]$/)
      item_sym = item.to_sym
      if match && available_includes.include?(match[1].to_sym) && !was_seen
        seen_objects << model_name
        item_sym = match[1].to_sym
        item_array = self.split_only_string(match[2])
        model.associated_models(match[1]).each do |m|
          item_array = self.get_includes_array(item_array, m, seen_objects)
          include_array << Hash[item_sym, item_array]
        end
      elsif available_includes.include?(item_sym) && !was_seen
        include_array << item_sym
      end
    end
    include_array
  end
end
