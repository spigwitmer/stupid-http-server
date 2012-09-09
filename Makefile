ERL_SRCDIR = src
ERL_SRCS = $(wildcard $(ERL_SRCDIR)/*.erl)

ERL_EBINDIR = ebin
ERL_OBJS = $(patsubst $(ERL_SRCDIR)/%, $(ERL_EBINDIR)/%, $(ERL_SRCS:%.erl=%.beam))

ERLC_FLAGS = -I include -o $(ERL_EBINDIR) $(ERLC_ADD)
ERLC ?= erlc

$(ERL_EBINDIR)/%.beam: $(ERL_SRCDIR)/%.erl
	$(ERLC) $(ERLC_FLAGS) $<

http_start: $(ERL_OBJS)
	
clean:
	rm -rf ebin/*.beam

all: http_start
