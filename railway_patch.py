"""Small runtime fixes for Excalibur on Railway, applied before the app loads.

A table-extraction job runs in a child process. If that child dies (for
example the kernel kills it for using too much memory on a huge page),
upstream only prints a traceback and the page says "Processing" forever.
This records an error on the file or job instead, so the page shows it, and
starts a fresh task pool if the pool's own worker was killed.
"""
import subprocess
import sys

from excalibur.executors import sequential_executor

_original = sequential_executor.execute_command


def _record_failure(command, returncode):
    try:
        from excalibur import tasks
        from excalibur.models import File, Job

        task_name, task_id = command[-3], command[-1]
        if returncode < 0 or returncode == 137:
            why = (
                "The worker process was stopped (signal %d). This usually means "
                "it ran out of memory: try fewer pages at once, or give the "
                "service more RAM." % (-returncode if returncode < 0 else 9)
            )
        else:
            why = "The worker process exited with code %d." % returncode
        exc = RuntimeError(why)
        if task_name == "split":
            tasks._record_error(File, File.file_id, task_id, exc)
        elif task_name == "extract":
            tasks._record_error(Job, Job.job_id, task_id, exc)
    except Exception as e:  # never break the executor
        print("railway_patch: could not record failure: %r" % (e,), file=sys.stderr)


def execute_command(command):
    try:
        subprocess.check_call(command, stderr=subprocess.STDOUT)  # noqa: S603
    except subprocess.CalledProcessError as e:
        print("railway_patch: task %s failed with code %s" % (command[-3:], e.returncode),
              file=sys.stderr)
        _record_failure(command, e.returncode)
    except Exception:
        _original(command)


sequential_executor.execute_command = execute_command


def _execute_async(self, command):
    # If the pool's worker itself was killed, the pool is broken for good and
    # every later upload would fail with a 500. Start a fresh pool instead.
    try:
        self.pool.submit(execute_command, command)
    except Exception as e:
        print("railway_patch: restarting the task pool after %r" % (e,), file=sys.stderr)
        try:
            self.pool.shutdown(wait=False, cancel_futures=True)
        except Exception:
            pass
        self.start()
        self.pool.submit(execute_command, command)


sequential_executor.SequentialExecutor.execute_async = _execute_async
