function! s:RSpecCurrent()
  ruby <<RUBY
using Module.new {
  refine RubyVM::AbstractSyntaxTree::Node do
    def traverse(*types, &block)
      if block_given?
        children.each do |node|
          yield(node) if node.respond_to?(:type) && (types.empty? || types.include?(node.type))
          node.traverse(*types, &block) if node.respond_to?(:traverse)
        end
      else
        to_enum(:traverse, *types)
      end
    end

    def parent_of?(other)
      children.map(&:node_id).include?(other.node_id)
    end
  end
}

class RspecCurrent
  def initialize(filename = nil, line = nil)
    current_buffer = VIM::Buffer.current
    @buffer_contents = (fllename && line) ? File.read(filename) : current_buffer.get_lines(0, current_buffer.count)
    @filename = filename || current_buffer.name
    @line = line || current_buffer.line
  end

  def ast
    @ast ||= RubyVM::AbstractSyntaxTree.parse(@buffer_contents.join)
  end

  def current_node
    c = nil
    min_distance = 10000 # 10000 is MAX

    # Find the current node
    ast.traverse do |node|
      distance = @line - node.first_lineno
      break if distance < 0

      if distance < min_distance
        min_distance = distance
        c = node
      end
    end
    c
  end

  def method_nodes_with_name(*names)
    nodes = []

    ast.traverse(:FCALL) do |node|
      if names.map(&:to_sym).include? node.children[0]
        nodes << node
      end
    end

    nodes
  end

  def parent_node_of(target)
    ast.traverse(:ITER) do |node|
      if node.parent_of?(target)
        break node
      end
    end
  end

  def string_for(node)
    start_line = node.first_lineno
    end_line = node.last_lineno
    @buffer_contents[(start_line - 1)..(end_line - 1)].map(&:strip).join("\n")
  end

  def closest_node(nodes)
    distances = nodes.map do |node|
      current_node.first_lineno - node.first_lineno
    end

    min_distance = distances.reject(&:negative?).min
    nodes[distances.index(min_distance)]
  end

  def subject
    subject_nodes = method_nodes_with_name(:subject)
    string_for(parent_node_of(closest_node(subject_nodes)))
  end

  def context
    context_nodes = method_nodes_with_name(:context)
    context_nodes = method_nodes_with_name(:describe) if context_nodes.empty?
    closest_node(context_nodes).children[1].children[0].children[0]
  end

  def lets
    let_nodes = method_nodes_with_name(:let, :let!).select {|node| node.first_lineno < current_node.first_lineno }
    grouped_let_nodes = let_nodes.group_by do |node|
      node.children[1].children[0].children[0] # Name for let, 'foo' for let(:foo)
    end
    grouped_let_nodes.map do |name, nodes|
      string_for(parent_node_of(closest_node(nodes)))
    end
  end

  def klass
    class_nodes = []
    ast.traverse(:CLASS) do |node|
      class_nodes << node
    end
    closest_node(class_nodes).children[0].children[1]
  end
end
RUBY
endfunction

function! RSpecCurrentContext()
  call s:RSpecCurrent()
  return rubyeval('RspecCurrent.new.context')
endfunction

function! RSpecCurrentSubject()
  call s:RSpecCurrent()
  return rubyeval('RspecCurrent.new.subject')
endfunction
