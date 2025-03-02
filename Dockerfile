ARG PYTHON_BASE_IMAGE=quay.io/ansible/python-base:latest
ARG PYTHON_BUILDER_IMAGE=quay.io/ansible/python-builder:latest
ARG ANSIBLE_BRANCH=""
ARG ZUUL_SIBLINGS=""

FROM $PYTHON_BUILDER_IMAGE as builder
# =============================================================================

COPY . /tmp/src
RUN if [ "$ANSIBLE_BRANCH" != "" ] ; then \
      echo "Installing requirements.txt / upper-constraints.txt for Ansible $ANSIBLE_BRANCH" ; \
      cp /tmp/src/tools/requirements-$ANSIBLE_BRANCH.txt /tmp/src/requirements.txt ; \
      cp /tmp/src/tools/upper-constraints-$ANSIBLE_BRANCH.txt /tmp/src/upper-constraints.txt ; \
    else \
      echo "Installing requirements.txt" ; \
      cp /tmp/src/tools/requirements.txt /tmp/src/requirements.txt ; \
    fi
RUN assemble

FROM $PYTHON_BASE_IMAGE
# =============================================================================

COPY --from=builder /output/ /output
RUN /output/install-from-bindep \
  && rm -rf /output

# In OpenShift, container will run as a random uid number and gid 0. Make sure things
# are writeable by the root group.
RUN for dir in \
      /home/runner \
      /home/runner/.ansible \
      /home/runner/.ansible/tmp \
      /runner \
      /home/runner \
      /runner/env \
      /runner/inventory \
      /runner/project \
      /runner/artifacts ; \
    do mkdir -m 0775 -p $dir ; chmod -R g+rwx $dir ; chgrp -R root $dir ; done && \
    for file in \
      /home/runner/.ansible/galaxy_token \
      /etc/passwd \
      /etc/group ; \
    do touch $file ; chmod g+rw $file ; chgrp root $file ; done

VOLUME /runner

WORKDIR /runner

ENV HOME=/home/runner

ADD utils/entrypoint.sh /bin/entrypoint
RUN chmod +x /bin/entrypoint

ENTRYPOINT ["entrypoint"]
CMD ["ansible-runner", "run", "/runner"]
