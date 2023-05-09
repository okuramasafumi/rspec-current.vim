function! s:RSpecCurrent()
  ruby <<RUBY
using Module.new {
  refine RubyVM::AbstractSyntaxTree::Node do
    def parent = nil

    def traverse(*types, &block)
      if block_given?
        children.each do |node|
          if node.is_a?(RubyVM::AbstractSyntaxTree::Node)
            s = self
            node.define_singleton_method(:parent) { s }
          end
          yield(node) if node.respond_to?(:type) && (types.empty? || types.include?(node.type))
          node.traverse(*types, &block) if node.respond_to?(:traverse)
        end
        nil
      else
        to_enum(:traverse, *types)
      end
    end

    def subtree_for(node_id)
      subtree = children.select do |nn|
        next unless nn.is_a?(RubyVM::AbstractSyntaxTree::Node)

        nnn = nn.children.last
        next unless nnn.is_a?(RubyVM::AbstractSyntaxTree::Node)

        result = nnn.traverse do |nnnn|
          break :found if nnnn.node_id == node_id
        end
        result == :found
      end
      return subtree.first unless subtree.empty?
    end
  end
}

class RSpecCurrent
  def initialize(filename = nil, line = nil)
    current_buffer = VIM::Buffer.current
    @buffer_contents = (filename && line) ? File.read(filename) : current_buffer.lines.to_a
    @filename = filename || current_buffer.name
    @line = line || current_buffer.line_number
  end

  def ast
    @ast ||= RubyVM::AbstractSyntaxTree.parse(@buffer_contents.join("\n"), keep_tokens: true, error_tolerant: true)
  end

  def rspec?
    @filename&.end_with?('_spec.rb')
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

  def method_nodes_with_name(*names, ast: self.ast)
    nodes = []

    ast.traverse(:FCALL) do |node|
      if names.map(&:to_sym).include? node.children[0]
        nodes << node
      end
    end

    nodes
  end

  def string_for(target)
    raise "Target is nil" if target.nil?

    case target.children.first
    when :subject
      target.parent.children.last.children.last.children.last
    when :context
      target.children.last.children.first.children.first
    end
  end

  def closest_node(nodes)
    distances = nodes.map do |node|
      current_node.first_lineno - node.first_lineno
    end

    min_distance = distances.reject(&:negative?).min
    nodes[distances.index(min_distance)]
  end

  def subtree
    ast.subtree_for(current_node.node_id)
  end

  def subject_node_in_parent_chain
    node = current_node
    while node
      sn = node.children.find { _1.respond_to?(:type) && _1.type == :ITER && _1.children[0].type == :FCALL && _1.children[0].children[0] == :subject }
      break sn if sn
      node = node.parent
    end
  end

  def subject
    return '' unless rspec?

    node = subject_node_in_parent_chain
    node.children.last.children.last.tokens.map { _1[2] }.join
  end

  def context
    return '' unless rspec?

    context_nodes = method_nodes_with_name(:context, ast: subtree)
    string_for(closest_node(context_nodes))
  end

  def lets
    return '' unless rspec?

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
  return rubyeval('RSpecCurrent.new.context')
endfunction

function! RSpecCurrentSubject()
  call s:RSpecCurrent()
  return rubyeval('RSpecCurrent.new.subject')
endfunction
