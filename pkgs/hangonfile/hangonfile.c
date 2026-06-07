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

  inotifywait -qq -e delete_self '${cfg.keyStore}/${name}' &

  if ! [ -e '${cfg.keyStore}/${name}' ]; then
    echo 'flapped down'
    exit 0
  fi

  wait %1

To compile it use (-lpthread is not needed since GLibc 2.34):
  $ gcc -O2 -Wall -Werror hangonfile.c -o hangonfile

For the motivation see wait4file.c

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
hangonfile_loop (int fd)
{
  char buf[sizeof (struct inotify_event)]
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

          if (ev->mask & IN_MOVE_SELF)
            {
              fprintf (stderr, "The file was moved\n");
            }
          else if (ev->mask & IN_DELETE_SELF)
            {
              fprintf (stderr, "The file was deleted\n");
            }
          else
            {
              fprintf (stderr, "Unexpected inotify event: %u\n", ev->mask);
            }

        }

      return EXIT_SUCCESS;
    }
}

static void *
hangonfile_thread (void *arg)
{
  return (void *) (intptr_t) hangonfile_loop ((int) (intptr_t) arg);
}

static int
hangonfile (const char *filename)
{
  int fd = inotify_init ();
  if (fd < 0)
    {
      perror ("inotify_init");
      return EXIT_FAILURE;
    }

  int wd = inotify_add_watch (fd, filename, IN_DELETE_SELF | IN_MOVE_SELF);
  if (wd < 0)
    {
      perror ("inotify_add_watch");
      (void) close (fd);
      return EXIT_FAILURE;
    }

  pthread_t tid;

  if (pthread_create (&tid, NULL, hangonfile_thread, (void *) (intptr_t) fd))
    {
      perror ("pthread_create");
      (void) close (fd);
      return EXIT_FAILURE;
    }

  // How when inotify is secured, let's check if the file is gone afterwards:
  if (0 != access (filename, F_OK))
    {
      fprintf (stderr, "The file is gone");
      pthread_cancel (tid);
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
      fprintf (stdout, "Wait for a file to disappear. Usage: %s <FILENAME>\n",
               argv[0]);
      return EXIT_SUCCESS;
    }

  return hangonfile (argv[1]);
}
