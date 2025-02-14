# sjtu_canvas_downloader

A bash script to download course files from SJTU canvas



在同文件夹里应创建：

- `token.txt`，内容为你的 canvas token
- `courses.txt`，内容为你要下载的课程
  - 第一行有一个数字，表示课程数量
  - 之后第一行是课程名，第二行是课程 id，共有课程数量*2行
  - 对于每门课创建一个课程名字的文件夹，在文件夹里面下载文件
- `path.txt`，内容为你要下载的文件的路径($HOME 的相对路径)
- 可以查看`example`文件夹里的例子
