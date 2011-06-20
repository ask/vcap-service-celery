======
 TODO
======


Automaticallly provision message transport when bound to app.
=============================================================

Where message transport can currently be one of rabbit, redis, mongodb,
mysql or postgresql.

Not sure how services should provision other services yet.

Services are exposed to apps by the :envvar:`VCAP_SERVICES` environment
variable, the keys consists of the service name and the values
are the responses returned by ``Service.bind_service``.

e.g.::

    >>> VCAP_SERVICES = {"rabbit": {"name": "rabbit1", "vhost": "/foo", ...}}


So what do we do for subservices?

Either::


    >>> VCAP_SERVICES = {"celery": {"name": "celery1",
    ...                         "rabbit": {"name": "rabbit1",
    ...                                    "vhost": "/foo", ...}}


or::

    >>> VCAP_SERVICES = {"celery": {"name": "celery1"},
    ...                  "rabbit": {"name": "rabbit1", "vhost": "/foo", ...}}


I'd guess latter is preferable.


Automatically provision result store.
=====================================

Same as above.


Load tasks from app
===================

This is a Python only thing, so guess we can hold off from this for now.
The default service will support webhook tasks anyway.


Install dependencies on setup
=============================

Celery and python-setuptools etc.

