/*
 DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.
*/

/*
This C program implements roughly what NixOps used to do
in its systemd services for keys (pieces of secret info):

  (while read f; do if [ "$f" = "${keyCfg.name}" ]; then break; fi; done \
  < <(inotifywait -qm --format '%f' -e create,move ${keyCfg.destDir}) ) &

  if [[ -e "${keyCfg.path}" ]]; then
    echo 'flapped down'
    kill %1
    exit 0
  fi
  wait %1

To compile it use (-lpthread is not needed since GLibc 2.34):
  $ gcc -O2 -Wall -Werror wait4file.c -o wait4file

Why this program exists.

Waiting for a file could be as simple as `while ! [ -e /foo/bar ]; do sleep 1s; done`.
Clearly, such polling is a waste of resources. Better is to wait until the kernel tells us
the file is flapped down.

Here comes inotifywait. And a race condition: if the file already exists before an
inotify watch is added, inotifywait will likely hang forever because a corresponding event
(e. g. move_to, close_write) will never be triggered, so we can't rely on testing the file's
existence before starting inotifywait (the test-add-wait scheme).  Also we cannot start
inotifywait before testing the file's existence because inotifywait will block the process
(the add-wait-test scheme).

NixOps tried to solve this issue by starting inotifywait first in a sub-shell so that it
does not block the following test for the file's existence. But this approach does not really
solves the problem because testing the file's existence still can happen before adding
a watch somewhere within inotifywait: two shells (test & add-wait) run concurrently.
A better solution is to add a watch first, then test for the file's existence, then start
waiting for a corresponding event if necessary (the add-test-wait scheme). At this moment
inotifywait is off the table. The sequential add-test-wait scheme has one theoretical issue:
the inotify event queue can overflow and events can be lost.  To prevent loss of events
the gap between the "add" and "wait" steps has to be as small as possible, so we start the
"wait" and "test" steps concurrently right after the "add" step.

P. S. This program also solves a systemd's complain:
 "Found left-over process 16707 (inotifywait) in control group while starting unit. Ignoring."

*/

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/inotify.h>

static int
wait4file_loop (int fd, const char *filename)
{
  char buf[4096]
    __attribute__((aligned (__alignof__ (struct inotify_event))));
  const struct inotify_event *ev;
  ssize_t size;

  while (1)
    {
      size = read (fd, buf, sizeof (buf));
      if (size < 0)
        {
          if (errno != EAGAIN)
            {
              perror ("read");
              return EXIT_FAILURE;
            }
          else
            {
              continue;
            }
        }

      for (const char *p = buf; p < buf + size;
           p += sizeof (struct inotify_event) + ev->len)
        {
          ev = (const struct inotify_event *) p;

          if (0 == strncmp (filename, ev->name, ev->len))
            {
              if (ev->mask & IN_MOVED_TO)
                {
                  fprintf (stderr, "The file was moved in\n");
                }
              else if (ev->mask & IN_CLOSE_WRITE)
                {
                  fprintf (stderr, "The file was written to\n");
                }
              else
                {
                  fprintf (stderr, "Unexpected inotify event: %u\n",
                           ev->mask);
                }

              return EXIT_SUCCESS;
            }
        }
    }
}

struct wait4file_loop_args
{
  int fd;
  const char *filename;
};

static void *
wait4file_thread (void *arg)
{
  struct wait4file_loop_args *args = (struct wait4file_loop_args *) arg;
  return (void *) (intptr_t) wait4file_loop (args->fd, args->filename);
}

static int
wait4file (const char *dirname, const char *filename)
{
  int fd = inotify_init ();
  if (fd < 0)
    {
      perror ("inotify_init");
      return EXIT_FAILURE;
    }

  int wd = inotify_add_watch (fd, dirname, IN_CLOSE_WRITE | IN_MOVED_TO);
  if (wd < 0)
    {
      perror ("inotify_add_watch");
      (void) close (fd);
      return EXIT_FAILURE;
    }

  pthread_t tid;
  struct wait4file_loop_args arg;

  arg.fd = fd;
  arg.filename = filename;

  if (pthread_create (&tid, NULL, wait4file_thread, (void *) &arg))
    {
      perror ("pthread_create");
      (void) close (fd);
      return EXIT_FAILURE;
    }

  // How when inotify is secured, let's check if the file already exists:
  int dirfd = open (dirname, O_DIRECTORY);
  if ((dirfd > 0) && (0 == faccessat (dirfd, filename, F_OK, 0)))
    {
      fprintf (stderr, "The file exists\n");
      pthread_cancel (tid);
      (void) close (dirfd);
    }

  // Wait for the inotify thread to report back:
  void *ret;
  if (pthread_join (tid, &ret))
    {
      perror ("pthread_join");
      (void) close (fd);
      return EXIT_FAILURE;
    }

  (void) close (fd);

  return ret == PTHREAD_CANCELED ? EXIT_SUCCESS : (intptr_t) ret;
}

int
main (int argc, char *argv[])
{
  if (argc != 2)
    {
      fprintf (stderr, "Usage: %s <FILENAME>\n", argv[0]);
      return EXIT_FAILURE;
    }

  if (0 == strcmp ("--help", argv[1]) || 0 == strcmp ("-h", argv[1]))
    {
      fprintf (stdout, "Wait for a file to appear. Usage: %s <FILENAME>\n",
               argv[0]);
      return EXIT_SUCCESS;
    }

  const char *dirname = ".";
  const char *filename = argv[1];

  char *sep = (char *) strrchr (filename, '/');

  if (sep)
    {
      if (sep == filename)
        {
          dirname = "/";
        }
      else
        {
          *sep = '\0';
          dirname = filename;
        }
      filename = sep + 1;
    }

  return wait4file (dirname, filename);
}
