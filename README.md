# SubSub

Elixir Project for associating subtitles files to video files by simply renaming subtitles files path  
Possibility to match a title in the video or subtitles files for renaming both  

For the regexs, you must use:  
`%s` for matching season number `(\d+)`  
`%e` for matching episode number  `(\d+)`  
and optionnaly:  
`%t` for matching title `(.+)`

Usage: `sub_sub -vr regex -sr regex [options] directory`

Example for:
```
/tmp/the_expanse/s1/
  The.Expanse-S01E03-Remember.the.Canterbury.mkv 
  the_expanse-01x03.srt
```
`sub_sub --video-regex "S%sE%e-%t\\.mkv$" --sub-regex "-%sx%e\\.srt$" --replace "The Expanse - S%sE%e - %t" /tmp/the_expanse/s1/`
