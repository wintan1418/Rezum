class ResumeDiffService
  def initialize(original:, optimized:)
    @original = original.to_s
    @optimized = optimized.to_s
  end

  def generate_html_diff
    original_lines = @original.split("\n")
    optimized_lines = @optimized.split("\n")

    diff_lines = compute_diff(original_lines, optimized_lines)
    diff_lines.map { |type, line| format_line(type, line) }.join("\n")
  end

  private

  def compute_diff(old_lines, new_lines)
    result = []
    old_set = old_lines.map(&:strip)
    new_set = new_lines.map(&:strip)

    # Simple line-by-line diff using LCS approach
    lcs = longest_common_subsequence(old_set, new_set)
    old_idx = 0
    new_idx = 0
    lcs_idx = 0

    while old_idx < old_set.length || new_idx < new_set.length
      if lcs_idx < lcs.length
        # Skip removed lines (in old but not in LCS)
        while old_idx < old_set.length && old_set[old_idx] != lcs[lcs_idx]
          result << [ :removed, old_lines[old_idx] ]
          old_idx += 1
        end

        # Skip added lines (in new but not in LCS)
        while new_idx < new_set.length && new_set[new_idx] != lcs[lcs_idx]
          result << [ :added, new_lines[new_idx] ]
          new_idx += 1
        end

        # Common line
        if old_idx < old_set.length && new_idx < new_set.length
          result << [ :unchanged, new_lines[new_idx] ]
          old_idx += 1
          new_idx += 1
          lcs_idx += 1
        end
      else
        # Remaining old lines are removed
        while old_idx < old_set.length
          result << [ :removed, old_lines[old_idx] ]
          old_idx += 1
        end
        # Remaining new lines are added
        while new_idx < new_set.length
          result << [ :added, new_lines[new_idx] ]
          new_idx += 1
        end
      end
    end

    result
  end

  def longest_common_subsequence(a, b)
    m = a.length
    n = b.length
    dp = Array.new(m + 1) { Array.new(n + 1, 0) }

    (1..m).each do |i|
      (1..n).each do |j|
        dp[i][j] = if a[i - 1] == b[j - 1]
                     dp[i - 1][j - 1] + 1
        else
                     [ dp[i - 1][j], dp[i][j - 1] ].max
        end
      end
    end

    # Backtrack to find LCS
    result = []
    i, j = m, n
    while i > 0 && j > 0
      if a[i - 1] == b[j - 1]
        result.unshift(a[i - 1])
        i -= 1
        j -= 1
      elsif dp[i - 1][j] > dp[i][j - 1]
        i -= 1
      else
        j -= 1
      end
    end

    result
  end

  def format_line(type, line)
    escaped = ERB::Util.html_escape(line)
    case type
    when :added
      %(<div class="diff-line diff-added">#{escaped}</div>)
    when :removed
      %(<div class="diff-line diff-removed">#{escaped}</div>)
    when :unchanged
      %(<div class="diff-line diff-unchanged">#{escaped}</div>)
    end
  end
end
