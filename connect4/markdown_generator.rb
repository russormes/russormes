require_relative './game'

class MarkdownGenerator
  IMAGE_BASE_URL = 'https://raw.githubusercontent.com/russormes/russormes/master/images'
  ISSUE_BASE_URL = 'https://github.com/russormes/russormes/issues/new'

  RED_IMAGE = "![](#{IMAGE_BASE_URL}/red.png)"
  BLUE_IMAGE = "![](#{IMAGE_BASE_URL}/blue.png)"
  BLANK_IMAGE = "![](#{IMAGE_BASE_URL}/blank.png)"

  def initialize(game:, octokit:)
    @game = game
    @octokit = octokit
  end

  def generate
    current_turn = game.current_turn

    game_winning_move_flag = false
    game_winning_players = Hash.new(0)
    players = Hash.new(0)
    total_moves_played = 0
    completed_games = 0
    @octokit.issues.each do |issue|
      players[issue.user.login] += 1
      if issue.title == 'connect4|new'
        game_winning_move_flag = true
        completed_games += 1
      else
        total_moves_played += 1
        if game_winning_move_flag
          game_winning_move_flag = false
          if issue.title.end_with?('ai')
            game_winning_players['Connect4Bot'] += 1
          else
            game_winning_players[issue.user.login] += 1
          end
        end
      end
    end

    game_winning_players = game_winning_players.sort_by { |_, wins| -wins }

    markdown = <<~HTML
        # Hey, I'm Russell 👋

        [![Twitter Badge](https://img.shields.io/badge/-@NectarSoft-1ca0f1?style=flat-square&labelColor=1ca0f1&logo=twitter&logoColor=white&link=https://twitter.com/NectarSoft)](https://twitter.com/NectarSoft) [![Linkedin Badge](https://img.shields.io/badge/-RussOrmes-blue?style=flat-square&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/russellormes/)](https://www.linkedin.com/in/russellormes/)

        Hi. Russell here. A Principled Principal Engineer.
        
        ## :game_die: Join my community Connect Four game!
        ![](https://img.shields.io/badge/Moves%20played-#{total_moves_played}-blue)
        ![](https://img.shields.io/badge/Completed%20games-#{completed_games}-brightgreen)
        ![](https://img.shields.io/badge/Total%20players-#{players.size}-orange)

        Everyone is welcome to participate! To make a move, click on the **column number** you wish to drop your disk in.

    HTML

    game_status = if game.over?
      "Game over! #{game.status_string} [Click here to start a new game!](#{ISSUE_BASE_URL}?title=connect4%7Cnew)"
    else
      "It is the **#{current_turn}** team's turn to play."
    end

    markdown.concat("#{game_status}\n")

    valid_moves = game.valid_moves
    headers = (1..7).map do |column|
      if valid_moves.include?(column)
        "[#{column}](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7C#{column}&body=Just+push+%27Submit+new+issue%27.+You+don%27t+need+to+do+anything+else.)"
      else
        column.to_s
      end
    end

    markdown.concat("|#{headers.join('|')}|\n")
    markdown.concat("| - | - | - | - | - | - | - |\n")

    5.downto(0) do |row|
      format = (0...7).map do |col|
        offset = row + 7 * col
        if ((game.bitboards[0] >> offset) & 1) == 1
          RED_IMAGE
        elsif ((game.bitboards[1] >> offset) & 1) == 1
          BLUE_IMAGE
        else
          BLANK_IMAGE
        end
      end
      markdown.concat("|#{format.join('|')}|\n")
    end

    unless game.over?
      markdown.concat("\nTired of waiting? [Request a move](#{ISSUE_BASE_URL}?title=connect4%7Cdrop%7C#{current_turn}%7Cai&body=Just+push+%27Submit+new+issue%27.+You+don%27t+need+to+do+anything+else.) from Connect4Bot :robot: \n")
    end

    markdown.concat <<~HTML

        Interested in how everything works? [Click here](https://github.com/russormes/russormes/tree/master/connect4) to read up on what's happening behind the scenes.

        **:alarm_clock: Most recent moves**
        | Team | Move | Made by |
        | ---- | ---- | ------- |
    HTML

    count = 0
    octokit.issues.each do |issue|
      break if issue.title.start_with?('connect4|new')

      if issue.title.start_with?('connect4|drop|')
        count += 1
        *, team, move = issue.title.split('|')
        login = issue.user.login
        github_user = "[@#{login}](https://github.com/#{login})"
        user = if move == 'ai'
          comment = octokit.fetch_comments(issue_number: issue.number).find { |comment| comment.user.login == 'github-actions[bot]' }
          move = comment.body[/\*\*(\d)\*\*/, -1]
          "Connect4Bot on behalf of #{github_user}"
        else
          github_user
        end
        markdown.concat("| #{team.capitalize} | #{move} | #{user} |\n")
        break if count >= 3
      end
    end

    winning_moves_leaderboard = game_winning_players.map do |player, wins|
      user = if player == 'Connect4Bot'
        'Connect4Bot :robot:'
      else
        "[@#{player}](https://github.com/#{player})"
      end
      "| #{user} | #{wins} |"
    end.join("\n")

    markdown.concat <<~HTML

        **:trophy: Leaderboard: Most game winning moves :100:**
        | Player | Wins |
        | ------ | -----|
        #{winning_moves_leaderboard}
    HTML
  end

  private

  attr_reader :game, :octokit
end
