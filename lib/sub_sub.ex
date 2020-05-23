require Logger

defmodule SubSub.CLI do
  def parse_input_regex(input) do
    String.replace(input, "%s", "(?<s>[[:digit:]]+)")
    |> String.replace("%e", "(?<e>[[:digit:]]+)")
    |> String.replace("%t", "(?<t>.+)")
  end

  def parse_options(argv) do
    options = [
      strict:
        [
          video_regex: :string,
          sub_regex: :string,
          replace: :string,
          verbose: :count,
          placebo: :boolean,
          help: :boolean
        ],
      aliases:
        [
          vr: :video_regex,
          sr: :sub_regex,
          re: :replace,
          v: :verbose,
          p: :placebo,
          h: :help
        ]
    ]
    {opts, argv, _}= OptionParser.parse(argv, options)
    opts =
      Keyword.update(opts, :video_regex, nil, & SubSub.CLI.parse_input_regex(&1))
      |> Keyword.update(:sub_regex, nil, & SubSub.CLI.parse_input_regex(&1))
    {opts, argv}
  end

  def display_help() do
    IO.puts("""
      Usage: sub_sub -vr regex -sr regex [options] directory
      -vr: --video-regex regex | Matching videos filenames; %t for video title, %s for season number, %e for episode number
      -sr: --sub-regex regex   | Matching subtitles filenames; %t for video title, %s for season number, %e for episode number
      -re: --replace expression | Replace file names using given string. You can use %t fir title %s for the season and %e for the episode
      -v: --verbose | You know what it means
      -p: --placebo | Run the program empty
      -h: --help | Display this help mofo

      Example for a directory "/tmp/the_expanse/s1/" with "The.Expanse-S01E03-Remember.the.Canterbury.mkv" and "the_expanse-01x03.srt"
      sub_sub --video-regex "S%sE%e-%t\\.mkv$" --sub-regex "-%sx%e\\.srt$" --replace "The Expanse - S%sE%e - %t" /tmp/the_expanse/s1/
    """)
  end

  def main([]) do
    IO.puts("Usage: sub_sub directory. --help for help.")
  end

  def main(argv) do
    {opts, argv} = SubSub.CLI.parse_options(argv)
    if opts[:help] do
      SubSub.CLI.display_help()
    else
      SubSub.CLI.run(argv, opts)
    end
  end

  def run([dir], opts) do
    [video_regex, sub_regex] = for r <- [opts[:video_regex], opts[:sub_regex]], do: Regex.compile!(r, "u")
    %{subs: sub_files, videos: video_files} = Enum.reduce(File.ls!(dir), %{subs: [], videos: []}, fn f, acc ->
      cond do
        Regex.match?(video_regex, f) ->
          if opts[:verbose], do: IO.puts(IO.ANSI.green() <> "Parsing video '#{f}'" <> IO.ANSI.reset())
          parsed = Regex.named_captures(video_regex, f)
          file_info = %{
            "e" => String.pad_leading(parsed["e"], 2, "0"),
            "s" => String.pad_leading(parsed["s"], 2, "0"),
            "t" => parsed["t"] || "",
            "path" => Path.join(dir, f)
          }
          update_in(acc.videos, & [file_info | &1])
        Regex.match?(sub_regex, f) ->
          if opts[:verbose], do: IO.puts(IO.ANSI.blue() <> "Parsing subtitle '#{f}'" <> IO.ANSI.reset())
          parsed = Regex.named_captures(sub_regex, f)
          file_info = %{
            "e" => String.pad_leading(parsed["e"], 2, "0"),
            "s" => String.pad_leading(parsed["s"], 2, "0"),
            "t" => parsed["t"],
            "path" => Path.join(dir, f)
          }
          update_in(acc.subs, & [file_info | &1])
        true ->
          if opts[:verbose], do: IO.puts(:stderr, IO.ANSI.red() <> "Ignoring '#{f}'" <> IO.ANSI.reset())
          acc
      end
    end)
    Enum.map(video_files, fn %{"e" => e, "s" => s}=v ->
      case Enum.find(sub_files, fn %{"e" => ee, "s" => ss} -> e == ee and s == ss end) do
        %{"path" => sub_path, "t" => t} ->
          title = if v["t"] != "", do: v["t"], else: t
          new_name = opts[:replace] && (String.replace(opts[:replace], "%s", v["s"]) |> String.replace("%e", v["e"]) |> String.replace("%t", title)) || Path.basename(v["path"])
          new_video_path = Path.dirname(v["path"]) |> Path.join([new_name, Path.extname(v["path"])])
          Map.put(v, "sub_path", sub_path)
          |> Map.put("new_name", new_name)
          |> Map.put("new_path", new_video_path)
        nil -> v
      end
    end)
    |> Enum.filter(& Map.has_key?(&1, "sub_path"))
    |> Enum.sort(fn %{"s" => s1, "e" => e1}, %{"s" => s2, "e" => e2} ->
      case {String.to_integer(s1), String.to_integer(s2), String.to_integer(e1), String.to_integer(e2)} do
        {s, ss, _, _} when s > ss -> false
        {s, ss, _, _} when s < ss -> true
        {_, _, e, ee} when e > ee -> false
        {_, _, e, ee} when e < ee -> true
        _ ->
          IO.puts(:stderr, IO.ANSI.red() <> "Same episode multiple times..." <> IO.ANSI.reset())
          true
      end
    end)
  |> Enum.each(fn v ->
    new_sub_path = "#{Path.rootname(v["new_path"])}#{Path.extname(v["sub_path"])}"
    if opts[:verbose] do
      IO.puts(
        IO.ANSI.red()
        <> "'#{Path.basename(v["path"])}'"
        <> IO.ANSI.reset()
        <> " => "
        <> IO.ANSI.green()
        <> "'#{Path.basename(v["new_path"])}'"
        <> IO.ANSI.reset()
        <> " subtitled by "
        <> IO.ANSI.blue
        <> "'#{Path.basename(new_sub_path)}'"
        <> IO.ANSI.reset()
      )
    end
    unless opts[:placebo] do
      if opts[:replace], do: File.rename!(v["path"], v["new_path"])
      File.rename!(v["sub_path"], new_sub_path)
    end
  end)
  end
end
