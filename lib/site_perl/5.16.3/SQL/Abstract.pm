package SQL::Abstract; # see doc at end of file

use strict;
use warnings;
use Carp ();
use List::Util ();
use Scalar::Util ();

#======================================================================
# GLOBALS
#======================================================================

our $VERSION  = '1.77';

# This would confuse some packagers
$VERSION = eval $VERSION if $VERSION =~ /_/; # numify for warning-free dev releases

our $AUTOLOAD;

# special operators (-in, -between). May be extended/overridden by user.
# See section WHERE: BUILTIN SPECIAL OPERATORS below for implementation
my @BUILTIN_SPECIAL_OPS = (
  {regex => qr/^ (?: not \s )? between $/ix, handler => '_where_field_BETWEEN'},
  {regex => qr/^ (?: not \s )? in      $/ix, handler => '_where_field_IN'},
  {regex => qr/^ ident                 $/ix, handler => '_where_op_IDENT'},
  {regex => qr/^ value                 $/ix, handler => '_where_op_VALUE'},
  {regex => qr/^ is (?: \s+ not )?     $/ix, handler => '_where_field_IS'},
);

# unaryish operators - key maps to handler
my @BUILTIN_UNARY_OPS = (
  # the digits are backcompat stuff
  { regex => qr/^ and  (?: [_\s]? \d+ )? $/xi, handler => '_where_op_ANDOR' },
  { regex => qr/^ or   (?: [_\s]? \d+ )? $/xi, handler => '_where_op_ANDOR' },
  { regex => qr/^ nest (?: [_\s]? \d+ )? $/xi, handler => '_where_op_NEST' },
  { regex => qr/^ (?: not \s )? bool     $/xi, handler => '_where_op_BOOL' },
  { regex => qr/^ ident                  $/xi, handler => '_where_op_IDENT' },
  { regex => qr/^ value                  $/xi, handler => '_where_op_VALUE' },
);

#======================================================================
# DEBUGGING AND ERROR REPORTING
#======================================================================

sub _debug {
  return unless $_[0]->{debug}; shift; # a little faster
  my $func = (caller(1))[3];
  warn "[$func] ", @_, "\n";
}

sub belch (@) {
  my($func) = (caller(1))[3];
  Carp::carp "[$func] Warning: ", @_;
}

sub puke (@) {
  my($func) = (caller(1))[3];
  Carp::croak "[$func] Fatal: ", @_;
}


#======================================================================
# NEW
#======================================================================

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my %opt = (ref $_[0] eq 'HASH') ? %{$_[0]} : @_;

  # choose our case by keeping an option around
  delete $opt{case} if $opt{case} && $opt{case} ne 'lower';

  # default logic for interpreting arrayrefs
  $opt{logic} = $opt{logic} ? uc $opt{logic} : 'OR';

  # how to return bind vars
  $opt{bindtype} ||= 'normal';

  # default comparison is "=", but can be overridden
  $opt{cmp} ||= '=';

  # try to recognize which are the 'equality' and 'inequality' ops
  # (temporary quickfix (in 2007), should go through a more seasoned API)
  $opt{equality_op}   = qr/^( \Q$opt{cmp}\E | \= )$/ix;
  $opt{inequality_op} = qr/^( != | <> )$/ix;

  $opt{like_op}       = qr/^ (is\s+)? r?like $/xi;
  $opt{not_like_op}   = qr/^ (is\s+)? not \s+ r?like $/xi;

  # SQL booleans
  $opt{sqltrue}  ||= '1=1';
  $opt{sqlfalse} ||= '0=1';

  # special operators
  $opt{special_ops} ||= [];
  # regexes are applied in order, thus push after user-defines
  push @{$opt{special_ops}}, @BUILTIN_SPECIAL_OPS;

  # unary operators
  $opt{unary_ops} ||= [];
  push @{$opt{unary_ops}}, @BUILTIN_UNARY_OPS;

  # rudimentary sanity-check for user supplied bits treated as functions/operators
  # If a purported  function matches this regular expression, an exception is thrown.
  # Literal SQL is *NOT* subject to this check, only functions (and column names
  # when quoting is not in effect)

  # FIXME
  # need to guard against ()'s in column names too, but this will break tons of
  # hacks... ideas anyone?
  $opt{injection_guard} ||= qr/
    \;
      |
    ^ \s* go \s
  /xmi;

  return bless \%opt, $class;
}


sub _assert_pass_injection_guard {
  if ($_[1] =~ $_[0]->{injection_guard}) {
    my $class = ref $_[0];
    puke "Possible SQL injection attempt '$_[1]'. If this is indeed a part of the "
     . "desired SQL use literal SQL ( \'...' or \[ '...' ] ) or supply your own "
     . "{injection_guard} attribute to ${class}->new()"
  }
}


#======================================================================
# INSERT methods
#======================================================================

sub insert {
  my $self    = shift;
  my $table   = $self->_table(shift);
  my $data    = shift || return;
  my $options = shift;

  my $method       = $self->_METHOD_FOR_refkind("_insert", $data);
  my ($sql, @bind) = $self->$method($data);
  $sql = join " ", $self->_sqlcase('insert into'), $table, $sql;

  if ($options->{returning}) {
    my ($s, @b) = $self->_insert_returning ($options);
    $sql .= $s;
    push @bind, @b;
  }

  return wantarray ? ($sql, @bind) : $sql;
}

sub _insert_returning {
  my ($self, $options) = @_;

  my $f = $options->{returning};

  my $fieldlist = $self->_SWITCH_refkind($f, {
    ARRAYREF     => sub {join ', ', map { $self->_quote($_) } @$f;},
    SCALAR       => sub {$self->_quote($f)},
    SCALARREF    => sub {$$f},
  });
  return $self->_sqlcase(' returning ') . $fieldlist;
}

sub _insert_HASHREF { # explicit list of fields and then values
  my ($self, $data) = @_;

  my @fields = sort keys %$data;

  my ($sql, @bind) = $self->_insert_values($data);

  # assemble SQL
  $_ = $self->_quote($_) foreach @fields;
  $sql = "( ".join(", ", @fields).") ".$sql;

  return ($sql, @bind);
}

sub _insert_ARRAYREF { # just generate values(?,?) part (no list of fields)
  my ($self, $data) = @_;

  # no names (arrayref) so can't generate bindtype
  $self->{bindtype} ne 'columns'
    or belch "can't do 'columns' bindtype when called with arrayref";

  # fold the list of values into a hash of column name - value pairs
  # (where the column names are artificially generated, and their
  # lexicographical ordering keep the ordering of the original list)
  my $i = "a";  # incremented values will be in lexicographical order
  my $data_in_hash = { map { ($i++ => $_) } @$data };

  return $self->_insert_values($data_in_hash);
}

sub _insert_ARRAYREFREF { # literal SQL with bind
  my ($self, $data) = @_;

  my ($sql, @bind) = @${$data};
  $self->_assert_bindval_matches_bindtype(@bind);

  return ($sql, @bind);
}


sub _insert_SCALARREF { # literal SQL without bind
  my ($self, $data) = @_;

  return ($$data);
}

sub _insert_values {
  my ($self, $data) = @_;

  my (@values, @all_bind);
  foreach my $column (sort keys %$data) {
    my $v = $data->{$column};

    $self->_SWITCH_refkind($v, {

      ARRAYREF => sub {
        if ($self->{array_datatypes}) { # if array datatype are activated
          push @values, '?';
          push @all_bind, $self->_bindtype($column, $v);
        }
        else {                          # else literal SQL with bind
          my ($sql, @bind) = @$v;
          $self->_assert_bindval_matches_bindtype(@bind);
          push @values, $sql;
          push @all_bind, @bind;
        }
      },

      ARRAYREFREF => sub { # literal SQL with bind
        my ($sql, @bind) = @${$v};
        $self->_assert_bindval_matches_bindtype(@bind);
        push @values, $sql;
        push @all_bind, @bind;
      },

      # THINK : anything useful to do with a HASHREF ?
      HASHREF => sub {  # (nothing, but old SQLA passed it through)
        #TODO in SQLA >= 2.0 it will die instead
        belch "HASH ref as bind value in insert is not supported";
        push @values, '?';
        push @all_bind, $self->_bindtype($column, $v);
      },

      SCALARREF => sub {  # literal SQL without bind
        push @values, $$v;
      },

      SCALAR_or_UNDEF => sub {
        push @values, '?';
        push @all_bind, $self->_bindtype($column, $v);
      },

     });

  }

  my $sql = $self->_sqlcase('values')." ( ".join(", ", @values)." )";
  return ($sql, @all_bind);
}



#======================================================================
# UPDATE methods
#======================================================================


sub update {
  my $self  = shift;
  my $table = $self->_table(shift);
  my $data  = shift || return;
  my $where = shift;

  # first build the 'SET' part of the sql statement
  my (@set, @all_bind);
  puke "Unsupported data type specified to \$sql->update"
    unless ref $data eq 'HASH';

  for my $k (sort keys %$data) {
    my $v = $data->{$k};
    my $r = ref $v;
    my $label = $self->_quote($k);

    $self->_SWITCH_refkind($v, {
      ARRAYREF => sub {
        if ($self->{array_datatypes}) { # array datatype
          push @set, "$label = ?";
          push @all_bind, $self->_bindtype($k, $v);
        }
        else {                          # literal SQL with bind
          my ($sql, @bind) = @$v;
          $self->_assert_bindval_matches_bindtype(@bind);
          push @set, "$label = $sql";
          push @all_bind, @bind;
        }
      },
      ARRAYREFREF => sub { # literal SQL with bind
        my ($sql, @bind) = @${$v};
        $self->_assert_bindval_matches_bindtype(@bind);
        push @set, "$label = $sql";
        push @all_bind, @bind;
      },
      SCALARREF => sub {  # literal SQL without bind
        push @set, "$label = $$v";
      },
      HASHREF => sub {
        my ($op, $arg, @rest) = %$v;

        puke 'Operator calls in update must be in the form { -op => $arg }'
          if (@rest or not $op =~ /^\-(.+)/);

        local $self->{_nested_func_lhs} = $k;
        my ($sql, @bind) = $self->_where_unary_op ($1, $arg);

        push @set, "$label = $sql";
        push @all_bind, @bind;
      },
      SCALAR_or_UNDEF => sub {
        push @set, "$label = ?";
        push @all_bind, $self->_bindtype($k, $v);
      },
    });
  }

  # generate sql
  my $sql = $self->_sqlcase('update') . " $table " . $self->_sqlcase('set ')
          . join ', ', @set;

  if ($where) {
    my($where_sql, @where_bind) = $self->where($where);
    $sql .= $where_sql;
    push @all_bind, @where_bind;
  }

  return wantarray ? ($sql, @all_bind) : $sql;
}




#======================================================================
# SELECT
#======================================================================


sub select {
  my $self   = shift;
  my $table  = $self->_table(shift);
  my $fields = shift || '*';
  my $where  = shift;
  my $order  = shift;

  my($where_sql, @bind) = $self->where($where, $order);

  my $f = (ref $fields eq 'ARRAY') ? join ', ', map { $self->_quote($_) } @$fields
                                   : $fields;
  my $sql = join(' ', $self->_sqlcase('select'), $f,
                      $self->_sqlcase('from'),   $table)
          . $where_sql;

  return wantarray ? ($sql, @bind) : $sql;
}

#======================================================================
# DELETE
#======================================================================


sub delete {
  my $self  = shift;
  my $table = $self->_table(shift);
  my $where = shift;


  my($where_sql, @bind) = $self->where($where);
  my $sql = $self->_sqlcase('delete from') . " $table" . $where_sql;

  return wantarray ? ($sql, @bind) : $sql;
}


#======================================================================
# WHERE: entry point
#======================================================================



# Finally, a separate routine just to handle WHERE clauses
sub where {
  my ($self, $where, $order) = @_;

  # where ?
  my ($sql, @bind) = $self->_recurse_where($where);
  $sql = $sql ? $self->_sqlcase(' where ') . "( $sql )" : '';

  # order by?
  if ($order) {
    $sql .= $self->_order_by($order);
  }

  return wantarray ? ($sql, @bind) : $sql;
}


sub _recurse_where {
  my ($self, $where, $logic) = @_;

  # dispatch on appropriate method according to refkind of $where
  my $method = $self->_METHOD_FOR_refkind("_where", $where);

  my ($sql, @bind) =  $self->$method($where, $logic);

  # DBIx::Class directly calls _recurse_where in scalar context, so
  # we must implement it, even if not in the official API
  return wantarray ? ($sql, @bind) : $sql;
}



#======================================================================
# WHERE: top-level ARRAYREF
#======================================================================


sub _where_ARRAYREF {
  my ($self, $where, $logic) = @_;

  $logic = uc($logic || $self->{logic});
  $logic eq 'AND' or $logic eq 'OR' or puke "unknown logic: $logic";

  my @clauses = @$where;

  my (@sql_clauses, @all_bind);
  # need to use while() so can shift() for pairs
  while (my $el = shift @clauses) {

    # switch according to kind of $el and get corresponding ($sql, @bind)
    my ($sql, @bind) = $self->_SWITCH_refkind($el, {

      # skip empty elements, otherwise get invalid trailing AND stuff
      ARRAYREF  => sub {$self->_recurse_where($el)        if @$el},

      ARRAYREFREF => sub {
        my ($s, @b) = @$$el;
        $self->_assert_bindval_matches_bindtype(@b);
        ($s, @b);
      },

      HASHREF   => sub {$self->_recurse_where($el, 'and') if %$el},

      SCALARREF => sub { ($$el);                                 },

      SCALAR    => sub {# top-level arrayref with scalars, recurse in pairs
                        $self->_recurse_where({$el => shift(@clauses)})},

      UNDEF     => sub {puke "not supported : UNDEF in arrayref" },
    });

    if ($sql) {
      push @sql_clauses, $sql;
      push @all_bind, @bind;
    }
  }

  return $self->_join_sql_clauses($logic, \@sql_clauses, \@all_bind);
}

#======================================================================
# WHERE: top-level ARRAYREFREF
#======================================================================

sub _where_ARRAYREFREF {
    my ($self, $where) = @_;
    my ($sql, @bind) = @$$where;
    $self->_assert_bindval_matches_bindtype(@bind);
    return ($sql, @bind);
}

#======================================================================
# WHERE: top-level HASHREF
#======================================================================

sub _where_HASHREF {
  my ($self, $where) = @_;
  my (@sql_clauses, @all_bind);

  for my $k (sort keys %$where) {
    my $v = $where->{$k};

    # ($k => $v) is either a special unary op or a regular hashpair
    my ($sql, @bind) = do {
      if ($k =~ /^-./) {
        # put the operator in canonical form
        my $op = $k;
        $op = substr $op, 1;  # remove initial dash
        $op =~ s/^\s+|\s+$//g;# remove leading/trailing space
        $op =~ s/\s+/ /g;     # compress whitespace

        # so that -not_foo works correctly
        $op =~ s/^not_/NOT /i;

        $self->_debug("Unary OP(-$op) within hashref, recursing...");
        my ($s, @b) = $self->_where_unary_op ($op, $v);

        # top level vs nested
        # we assume that handled unary ops will take care of their ()s
        $s = "($s)" unless (
          List::Util::first {$op =~ $_->{regex}} @{$self->{unary_ops}}
            or
          defined($self->{_nested_func_lhs}) && ($self->{_nested_func_lhs} eq $k)
        );
        ($s, @b);
      }
      else {
        my $method = $self->_METHOD_FOR_refkind("_where_hashpair", $v);
        $self->$method($k, $v);
      }
    };

    push @sql_clauses, $sql;
    push @all_bind, @bind;
  }

  return $self->_join_sql_clauses('and', \@sql_clauses, \@all_bind);
}

sub _where_unary_op {
  my ($self, $op, $rhs) = @_;

  if (my $op_entry = List::Util::first {$op =~ $_->{regex}} @{$self->{unary_ops}}) {
    my $handler = $op_entry->{handler};

    if (not ref $handler) {
      if ($op =~ s/ [_\s]? \d+ $//x ) {
        belch 'Use of [and|or|nest]_N modifiers is deprecated and will be removed in SQLA v2.0. '
            . "You probably wanted ...-and => [ -$op => COND1, -$op => COND2 ... ]";
      }
      return $self->$handler ($op, $rhs);
    }
    elsif (ref $handler eq 'CODE') {
      return $handler->($self, $op, $rhs);
    }
    else {
      puke "Illegal handler for operator $op - expecting a method name or a coderef";
    }
  }

  $self->_debug("Generic unary OP: $op - recursing as function");

  $self->_assert_pass_injection_guard($op);

  my ($sql, @bind) = $self->_SWITCH_refkind ($rhs, {
    SCALAR =>   sub {
      puke "Illegal use of top-level '$op'"
        unless $self->{_nested_func_lhs};

      return (
        $self->_convert('?'),
        $self->_bindtype($self->{_nested_func_lhs}, $rhs)
      );
    },
    FALLBACK => sub {
      $self->_recurse_where ($rhs)
    },
  });

  $sql = sprintf ('%s %s',
    $self->_sqlcase($op),
    $sql,
  );

  return ($sql, @bind);
}

sub _where_op_ANDOR {
  my ($self, $op, $v) = @_;

  $self->_SWITCH_refkind($v, {
    ARRAYREF => sub {
      return $self->_where_ARRAYREF($v, $op);
    },

    HASHREF => sub {
      return ( $op =~ /^or/i )
        ? $self->_where_ARRAYREF( [ map { $_ => $v->{$_} } ( sort keys %$v ) ], $op )
        : $self->_where_HASHREF($v);
    },

    SCALARREF  => sub {
      puke "-$op => \\\$scalar makes little sense, use " .
        ($op =~ /^or/i
          ? '[ \$scalar, \%rest_of_conditions ] instead'
          : '-and => [ \$scalar, \%rest_of_conditions ] instead'
        );
    },

    ARRAYREFREF => sub {
      puke "-$op => \\[...] makes little sense, use " .
        ($op =~ /^or/i
          ? '[ \[...], \%rest_of_conditions ] instead'
          : '-and => [ \[...], \%rest_of_conditions ] instead'
        );
    },

    SCALAR => sub { # permissively interpreted as SQL
      puke "-$op => \$value makes little sense, use -bool => \$value instead";
    },

    UNDEF => sub {
      puke "-$op => undef not supported";
    },
   });
}

sub _where_op_NEST {
  my ($self, $op, $v) = @_;

  $self->_SWITCH_refkind($v, {

    SCALAR => sub { # permissively interpreted as SQL
      belch "literal SQL should be -nest => \\'scalar' "
          . "instead of -nest => 'scalar' ";
      return ($v);
    },

    UNDEF => sub {
      puke "-$op => undef not supported";
    },

    FALLBACK => sub {
      $self->_recurse_where ($v);
    },

   });
}


sub _where_op_BOOL {
  my ($self, $op, $v) = @_;

  my ($s, @b) = $self->_SWITCH_refkind($v, {
    SCALAR => sub { # interpreted as SQL column
      $self->_convert($self->_quote($v));
    },

    UNDEF => sub {
      puke "-$op => undef not supported";
    },

    FALLBACK => sub {
      $self->_recurse_where ($v);
    },
  });

  $s = "(NOT $s)" if $op =~ /^not/i;
  ($s, @b);
}


sub _where_op_IDENT {
  my $self = shift;
  my ($op, $rhs) = splice @_, -2;
  if (ref $rhs) {
    puke "-$op takes a single scalar argument (a quotable identifier)";
  }

  # in case we are called as a top level special op (no '=')
  my $lhs = shift;

  $_ = $self->_convert($self->_quote($_)) for ($lhs, $rhs);

  return $lhs
    ? "$lhs = $rhs"
    : $rhs
  ;
}

sub _where_op_VALUE {
  my $self = shift;
  my ($op, $rhs) = splice @_, -2;

  # in case we are called as a top level special op (no '=')
  my $lhs = shift;

  my @bind =
    $self->_bindtype (
      ($lhs || $self->{_nested_func_lhs}),
      $rhs,
    )
  ;

  return $lhs
    ? (
      $self->_convert($self->_quote($lhs)) . ' = ' . $self->_convert('?'),
      @bind
    )
    : (
      $self->_convert('?'),
      @bind,
    )
  ;
}

sub _where_hashpair_ARRAYREF {
  my ($self, $k, $v) = @_;

  if( @$v ) {
    my @v = @$v; # need copy because of shift below
    $self->_debug("ARRAY($k) means distribute over elements");

    # put apart first element if it is an operator (-and, -or)
    my $op = (
       (defined $v[0] && $v[0] =~ /^ - (?: AND|OR ) $/ix)
         ? shift @v
         : ''
    );
    my @distributed = map { {$k =>  $_} } @v;

    if ($op) {
      $self->_debug("OP($op) reinjected into the distributed array");
      unshift @distributed, $op;
    }

    my $logic = $op ? substr($op, 1) : '';

    return $self->_recurse_where(\@distributed, $logic);
  }
  else {
    $self->_debug("empty ARRAY($k) means 0=1");
    return ($self->{sqlfalse});
  }
}

sub _where_hashpair_HASHREF {
  my ($self, $k, $v, $logic) = @_;
  $logic ||= 'and';

  local $self->{_nested_func_lhs} = $self->{_nested_func_lhs};

  my ($all_sql, @all_bind);

  for my $orig_op (sort keys %$v) {
    my $val = $v->{$orig_op};

    # put the operator in canonical form
    my $op = $orig_op;

    # FIXME - we need to phase out dash-less ops
    $op =~ s/^-//;        # remove possible initial dash
    $op =~ s/^\s+|\s+$//g;# remove leading/trailing space
    $op =~ s/\s+/ /g;     # compress whitespace

    $self->_assert_pass_injection_guard($op);

    # fixup is_not
    $op =~ s/^is_not/IS NOT/i;

    # so that -not_foo works correctly
    $op =~ s/^not_/NOT /i;

    my ($sql, @bind);

    # CASE: col-value logic modifiers
    if ( $orig_op =~ /^ \- (and|or) $/xi ) {
      ($sql, @bind) = $self->_where_hashpair_HASHREF($k, $val, $1);
    }
    # CASE: special operators like -in or -between
    elsif ( my $special_op = List::Util::first {$op =~ $_->{regex}} @{$self->{special_ops}} ) {
      my $handler = $special_op->{handler};
      if (! $handler) {
        puke "No handler supplied for special operator $orig_op";
      }
      elsif (not ref $handler) {
        ($sql, @bind) = $self->$handler ($k, $op, $val);
      }
      elsif (ref $handler eq 'CODE') {
        ($sql, @bind) = $handler->($self, $k, $op, $val);
      }
      else {
        puke "Illegal handler for special operator $orig_op - expecting a method name or a coderef";
      }
    }
    else {
      $self->_SWITCH_refkind($val, {

        ARRAYREF => sub {       # CASE: col => {op => \@vals}
          ($sql, @bind) = $self->_where_field_op_ARRAYREF($k, $op, $val);
        },

        ARRAYREFREF => sub {    # CASE: col => {op => \[$sql, @bind]} (literal SQL with bind)
          my ($sub_sql, @sub_bind) = @$$val;
          $self->_assert_bindval_matches_bindtype(@sub_bind);
          $sql  = join ' ', $self->_convert($self->_quote($k)),
                            $self->_sqlcase($op),
                            $sub_sql;
          @bind = @sub_bind;
        },

        UNDEF => sub {          # CASE: col => {op => undef} : sql "IS (NOT)? NULL"
          my $is =
            $op =~ /^not$/i               ? 'is not'  # legacy
          : $op =~ $self->{equality_op}   ? 'is'
          : $op =~ $self->{like_op}       ? belch("Supplying an undefined argument to '@{[ uc $op]}' is deprecated") && 'is'
          : $op =~ $self->{inequality_op} ? 'is not'
          : $op =~ $self->{not_like_op}   ? belch("Supplying an undefined argument to '@{[ uc $op]}' is deprecated") && 'is not'
          : puke "unexpected operator '$orig_op' with undef operand";

          $sql = $self->_quote($k) . $self->_sqlcase(" $is null");
        },

        FALLBACK => sub {       # CASE: col => {op/func => $stuff}

          # retain for proper column type bind
          $self->{_nested_func_lhs} ||= $k;

          ($sql, @bind) = $self->_where_unary_op ($op, $val);

          $sql = join (' ',
            $self->_convert($self->_quote($k)),
            $self->{_nested_func_lhs} eq $k ? $sql : "($sql)",  # top level vs nested
          );
        },
      });
    }

    ($all_sql) = (defined $all_sql and $all_sql) ? $self->_join_sql_clauses($logic, [$all_sql, $sql], []) : $sql;
    push @all_bind, @bind;
  }
  return ($all_sql, @all_bind);
}

sub _where_field_IS {
  my ($self, $k, $op, $v) = @_;

  my ($s) = $self->_SWITCH_refkind($v, {
    UNDEF => sub {
      join ' ',
        $self->_convert($self->_quote($k)),
        map { $self->_sqlcase($_)} ($op, 'null')
    },
    FALLBACK => sub {
      puke "$op can only take undef as argument";
    },
  });

  $s;
}

sub _where_field_op_ARRAYREF {
  my ($self, $k, $op, $vals) = @_;

  my @vals = @$vals;  #always work on a copy

  if(@vals) {
    $self->_debug(sprintf '%s means multiple elements: [ %s ]',
      $vals,
      join (', ', map { defined $_ ? "'$_'" : 'NULL' } @vals ),
    );

    # see if the first element is an -and/-or op
    my $logic;
    if (defined $vals[0] && $vals[0] =~ /^ - ( AND|OR ) $/ix) {
      $logic = uc $1;
      shift @vals;
    }

    # a long standing API wart - an attempt to change this behavior during
    # the 1.50 series failed *spectacularly*. Warn instead and leave the
    # behavior as is
    if (
      @vals > 1
        and
      (!$logic or $logic eq 'OR')
        and
      ( $op =~ $self->{inequality_op} or $op =~ $self->{not_like_op} )
    ) {
      my $o = uc($op);
      belch "A multi-element arrayref as an argument to the inequality op '$o' "
          . 'is technically equivalent to an always-true 1=1 (you probably wanted '
          . "to say ...{ \$inequality_op => [ -and => \@values ] }... instead)"
      ;
    }

    # distribute $op over each remaining member of @vals, append logic if exists
    return $self->_recurse_where([map { {$k => {$op, $_}} } @vals], $logic);

  }
  else {
    # try to DWIM on equality operators
    return
      $op =~ $self->{equality_op}   ? $self->{sqlfalse}
    : $op =~ $self->{like_op}       ? belch("Supplying an empty arrayref to '@{[ uc $op]}' is deprecated") && $self->{sqlfalse}
    : $op =~ $self->{inequality_op} ? $self->{sqltrue}
    : $op =~ $self->{not_like_op}   ? belch("Supplying an empty arrayref to '@{[ uc $op]}' is deprecated") && $self->{sqltrue}
    : puke "operator '$op' applied on an empty array (field '$k')";
  }
}


sub _where_hashpair_SCALARREF {
  my ($self, $k, $v) = @_;
  $self->_debug("SCALAR($k) means literal SQL: $$v");
  my $sql = $self->_quote($k) . " " . $$v;
  return ($sql);
}

# literal SQL with bind
sub _where_hashpair_ARRAYREFREF {
  my ($self, $k, $v) = @_;
  $self->_debug("REF($k) means literal SQL: @${$v}");
  my ($sql, @bind) = @$$v;
  $self->_assert_bindval_matches_bindtype(@bind);
  $sql  = $self->_quote($k) . " " . $sql;
  return ($sql, @bind );
}

# literal SQL without bind
sub _where_hashpair_SCALAR {
  my ($self, $k, $v) = @_;
  $self->_debug("NOREF($k) means simple key=val: $k $self->{cmp} $v");
  my $sql = join ' ', $self->_convert($self->_quote($k)),
                      $self->_sqlcase($self->{cmp}),
                      $self->_convert('?');
  my @bind =  $self->_bindtype($k, $v);
  return ( $sql, @bind);
}


sub _where_hashpair_UNDEF {
  my ($self, $k, $v) = @_;
  $self->_debug("UNDEF($k) means IS NULL");
  my $sql = $self->_quote($k) . $self->_sqlcase(' is null');
  return ($sql);
}

#======================================================================
# WHERE: TOP-LEVEL OTHERS (SCALARREF, SCALAR, UNDEF)
#======================================================================


sub _where_SCALARREF {
  my ($self, $where) = @_;

  # literal sql
  $self->_debug("SCALAR(*top) means literal SQL: $$where");
  return ($$where);
}


sub _where_SCALAR {
  my ($self, $where) = @_;

  # literal sql
  $self->_debug("NOREF(*top) means literal SQL: $where");
  return ($where);
}


sub _where_UNDEF {
  my ($self) = @_;
  return ();
}


#======================================================================
# WHERE: BUILTIN SPECIAL OPERATORS (-in, -between)
#======================================================================


sub _where_field_BETWEEN {
  my ($self, $k, $op, $vals) = @_;

  my ($label, $and, $placeholder);
  $label       = $self->_convert($self->_quote($k));
  $and         = ' ' . $self->_sqlcase('and') . ' ';
  $placeholder = $self->_convert('?');
  $op               = $self->_sqlcase($op);

  my $invalid_args = "Operator '$op' requires either an arrayref with two defined values or expressions, or a single literal scalarref/arrayref-ref";

  my ($clause, @bind) = $self->_SWITCH_refkind($vals, {
    ARRAYREFREF => sub {
      my ($s, @b) = @$$vals;
      $self->_assert_bindval_matches_bindtype(@b);
      ($s, @b);
    },
    SCALARREF => sub {
      return $$vals;
    },
    ARRAYREF => sub {
      puke $invalid_args if @$vals != 2;

      my (@all_sql, @all_bind);
      foreach my $val (@$vals) {
        my ($sql, @bind) = $self->_SWITCH_refkind($val, {
           SCALAR => sub {
             return ($placeholder, $self->_bindtype($k, $val) );
           },
           SCALARREF => sub {
             return $$val;
           },
           ARRAYREFREF => sub {
             my ($sql, @bind) = @$$val;
             $self->_assert_bindval_matches_bindtype(@bind);
             return ($sql, @bind);
           },
           HASHREF => sub {
             my ($func, $arg, @rest) = %$val;
             puke ("Only simple { -func => arg } functions accepted as sub-arguments to BETWEEN")
               if (@rest or $func !~ /^ \- (.+)/x);
             local $self->{_nested_func_lhs} = $k;
             $self->_where_unary_op ($1 => $arg);
           },
           FALLBACK => sub {
             puke $invalid_args,
           },
        });
        push @all_sql, $sql;
        push @all_bind, @bind;
      }

      return (
        (join $and, @all_sql),
        @all_bind
      );
    },
    FALLBACK => sub {
      puke $invalid_args,
    },
  });

  my $sql = "( $label $op $clause )";
  return ($sql, @bind)
}


sub _where_field_IN {
  my ($self, $k, $op, $vals) = @_;

  # backwards compatibility : if scalar, force into an arrayref
  $vals = [$vals] if defined $vals && ! ref $vals;

  my ($label)       = $self->_convert($self->_quote($k));
  my ($placeholder) = $self->_convert('?');
  $op               = $self->_sqlcase($op);

  my ($sql, @bind) = $self->_SWITCH_refkind($vals, {
    ARRAYREF => sub {     # list of choices
      if (@$vals) { # nonempty list
        my (@all_sql, @all_bind);

        for my $val (@$vals) {
          my ($sql, @bind) = $self->_SWITCH_refkind($val, {
            SCALAR => sub {
              return ($placeholder, $val);
            },
            SCALARREF => sub {
              return $$val;
            },
            ARRAYREFREF => sub {
              my ($sql, @bind) = @$$val;
              $self->_assert_bindval_matches_bindtype(@bind);
              return ($sql, @bind);
            },
            HASHREF => sub {
              my ($func, $arg, @rest) = %$val;
              puke ("Only simple { -func => arg } functions accepted as sub-arguments to IN")
                if (@rest or $func !~ /^ \- (.+)/x);
              local $self->{_nested_func_lhs} = $k;
              $self->_where_unary_op ($1 => $arg);
            },
            UNDEF => sub {
              puke(
                'SQL::Abstract before v1.75 used to generate incorrect SQL when the '
              . "-$op operator was given an undef-containing list: !!!AUDIT YOUR CODE "
              . 'AND DATA!!! (the upcoming Data::Query-based version of SQL::Abstract '
              . 'will emit the logically correct SQL instead of raising this exception)'
              );
            },
          });
          push @all_sql, $sql;
          push @all_bind, @bind;
        }

        return (
          sprintf ('%s %s ( %s )',
            $label,
            $op,
            join (', ', @all_sql)
          ),
          $self->_bindtype($k, @all_bind),
        );
      }
      else { # empty list : some databases won't understand "IN ()", so DWIM
        my $sql = ($op =~ /\bnot\b/i) ? $self->{sqltrue} : $self->{sqlfalse};
        return ($sql);
      }
    },

    SCALARREF => sub {  # literal SQL
      my $sql = $self->_open_outer_paren ($$vals);
      return ("$label $op ( $sql )");
    },
    ARRAYREFREF => sub {  # literal SQL with bind
      my ($sql, @bind) = @$$vals;
      $self->_assert_bindval_matches_bindtype(@bind);
      $sql = $self->_open_outer_paren ($sql);
      return ("$label $op ( $sql )", @bind);
    },

    UNDEF => sub {
      puke "Argument passed to the '$op' operator can not be undefined";
    },

    FALLBACK => sub {
      puke "special op $op requires an arrayref (or scalarref/arrayref-ref)";
    },
  });

  return ($sql, @bind);
}

# Some databases (SQLite) treat col IN (1, 2) different from
# col IN ( (1, 2) ). Use this to strip all outer parens while
# adding them back in the corresponding method
sub _open_outer_paren {
  my ($self, $sql) = @_;
  $sql = $1 while $sql =~ /^ \s* \( (.*) \) \s* $/xs;
  return $sql;
}


#======================================================================
# ORDER BY
#======================================================================

sub _order_by {
  my ($self, $arg) = @_;

  my (@sql, @bind);
  for my $c ($self->_order_by_chunks ($arg) ) {
    $self->_SWITCH_refkind ($c, {
      SCALAR => sub { push @sql, $c },
      ARRAYREF => sub { push @sql, shift @$c; push @bind, @$c },
    });
  }

  my $sql = @sql
    ? sprintf ('%s %s',
        $self->_sqlcase(' order by'),
        join (', ', @sql)
      )
    : ''
  ;

  return wantarray ? ($sql, @bind) : $sql;
}

sub _order_by_chunks {
  my ($self, $arg) = @_;

  return $self->_SWITCH_refkind($arg, {

    ARRAYREF => sub {
      map { $self->_order_by_chunks ($_ ) } @$arg;
    },

    ARRAYREFREF => sub {
      my ($s, @b) = @$$arg;
      $self->_assert_bindval_matches_bindtype(@b);
      [ $s, @b ];
    },

    SCALAR    => sub {$self->_quote($arg)},

    UNDEF     => sub {return () },

    SCALARREF => sub {$$arg}, # literal SQL, no quoting

    HASHREF   => sub {
      # get first pair in hash
      my ($key, $val, @rest) = %$arg;

      return () unless $key;

      if ( @rest or not $key =~ /^-(desc|asc)/i ) {
        puke "hash passed to _order_by must have exactly one key (-desc or -asc)";
      }

      my $direction = $1;

      my @ret;
      for my $c ($self->_order_by_chunks ($val)) {
        my ($sql, @bind);

        $self->_SWITCH_refkind ($c, {
          SCALAR => sub {
            $sql = $c;
          },
          ARRAYREF => sub {
            ($sql, @bind) = @$c;
          },
        });

        $sql = $sql . ' ' . $self->_sqlcase($direction);

        push @ret, [ $sql, @bind];
      }

      return @ret;
    },
  });
}


#======================================================================
# DATASOURCE (FOR NOW, JUST PLAIN TABLE OR LIST OF TABLES)
#======================================================================

sub _table  {
  my $self = shift;
  my $from = shift;
  $self->_SWITCH_refkind($from, {
    ARRAYREF     => sub {join ', ', map { $self->_quote($_) } @$from;},
    SCALAR       => sub {$self->_quote($from)},
    SCALARREF    => sub {$$from},
  });
}


#======================================================================
# UTILITY FUNCTIONS
#======================================================================

# highly optimized, as it's called way too often
sub _quote {
  # my ($self, $label) = @_;

  return '' unless defined $_[1];
  return ${$_[1]} if ref($_[1]) eq 'SCALAR';

  unless ($_[0]->{quote_char}) {
    $_[0]->_assert_pass_injection_guard($_[1]);
    return $_[1];
  }

  my $qref = ref $_[0]->{quote_char};
  my ($l, $r);
  if (!$qref) {
    ($l, $r) = ( $_[0]->{quote_char}, $_[0]->{quote_char} );
  }
  elsif ($qref eq 'ARRAY') {
    ($l, $r) = @{$_[0]->{quote_char}};
  }
  else {
    puke "Unsupported quote_char format: $_[0]->{quote_char}";
  }

  # parts containing * are naturally unquoted
  return join( $_[0]->{name_sep}||'', map
    { $_ eq '*' ? $_ : $l . $_ . $r }
    ( $_[0]->{name_sep} ? split (/\Q$_[0]->{name_sep}\E/, $_[1] ) : $_[1] )
  );
}


# Conversion, if applicable
sub _convert ($) {
  #my ($self, $arg) = @_;
  if ($_[0]->{convert}) {
    return $_[0]->_sqlcase($_[0]->{convert}) .'(' . $_[1] . ')';
  }
  return $_[1];
}

# And bindtype
sub _bindtype (@) {
  #my ($self, $col, @vals) = @_;
  # called often - tighten code
  return $_[0]->{bindtype} eq 'columns'
    ? map {[$_[1], $_]} @_[2 .. $#_]
    : @_[2 .. $#_]
  ;
}

# Dies if any element of @bind is not in [colname => value] format
# if bindtype is 'columns'.
sub _assert_bindval_matches_bindtype {
#  my ($self, @bind) = @_;
  my $self = shift;
  if ($self->{bindtype} eq 'columns') {
    for (@_) {
      if (!defined $_ || ref($_) ne 'ARRAY' || @$_ != 2) {
        puke "bindtype 'columns' selected, you need to pass: [column_name => bind_value]"
      }
    }
  }
}

sub _join_sql_clauses {
  my ($self, $logic, $clauses_aref, $bind_aref) = @_;

  if (@$clauses_aref > 1) {
    my $join  = " " . $self->_sqlcase($logic) . " ";
    my $sql = '( ' . join($join, @$clauses_aref) . ' )';
    return ($sql, @$bind_aref);
  }
  elsif (@$clauses_aref) {
    return ($clauses_aref->[0], @$bind_aref); # no parentheses
  }
  else {
    return (); # if no SQL, ignore @$bind_aref
  }
}


# Fix SQL case, if so requested
sub _sqlcase {
  # LDNOTE: if $self->{case} is true, then it contains 'lower', so we
  # don't touch the argument ... crooked logic, but let's not change it!
  return $_[0]->{case} ? $_[1] : uc($_[1]);
}


#======================================================================
# DISPATCHING FROM REFKIND
#======================================================================

sub _refkind {
  my ($self, $data) = @_;

  return 'UNDEF' unless defined $data;

  # blessed objects are treated like scalars
  my $ref = (Scalar::Util::blessed $data) ? '' : ref $data;

  return 'SCALAR' unless $ref;

  my $n_steps = 1;
  while ($ref eq 'REF') {
    $data = $$data;
    $ref = (Scalar::Util::blessed $data) ? '' : ref $data;
    $n_steps++ if $ref;
  }

  return ($ref||'SCALAR') . ('REF' x $n_steps);
}

sub _try_refkind {
  my ($self, $data) = @_;
  my @try = ($self->_refkind($data));
  push @try, 'SCALAR_or_UNDEF' if $try[0] eq 'SCALAR' || $try[0] eq 'UNDEF';
  push @try, 'FALLBACK';
  return \@try;
}

sub _METHOD_FOR_refkind {
  my ($self, $meth_prefix, $data) = @_;

  my $method;
  for (@{$self->_try_refkind($data)}) {
    $method = $self->can($meth_prefix."_".$_)
      and last;
  }

  return $method || puke "cannot dispatch on '$meth_prefix' for ".$self->_refkind($data);
}


sub _SWITCH_refkind {
  my ($self, $data, $dispatch_table) = @_;

  my $coderef;
  for (@{$self->_try_refkind($data)}) {
    $coderef = $dispatch_table->{$_}
      and last;
  }

  puke "no dispatch entry for ".$self->_refkind($data)
    unless $coderef;

  $coderef->();
}




#======================================================================
# VALUES, GENERATE, AUTOLOAD
#======================================================================

# LDNOTE: original code from nwiger, didn't touch code in that section
# I feel the AUTOLOAD stuff should not be the default, it should
# only be activated on explicit demand by user.

sub values {
    my $self = shift;
    my $data = shift || return;
    puke "Argument to ", __PACKAGE__, "->values must be a \\%hash"
        unless ref $data eq 'HASH';

    my @all_bind;
    foreach my $k ( sort keys %$data ) {
        my $v = $data->{$k};
        $self->_SWITCH_refkind($v, {
          ARRAYREF => sub {
            if ($self->{array_datatypes}) { # array datatype
              push @all_bind, $self->_bindtype($k, $v);
            }
            else {                          # literal SQL with bind
              my ($sql, @bind) = @$v;
              $self->_assert_bindval_matches_bindtype(@bind);
              push @all_bind, @bind;
            }
          },
          ARRAYREFREF => sub { # literal SQL with bind
            my ($sql, @bind) = @${$v};
            $self->_assert_bindval_matches_bindtype(@bind);
            push @all_bind, @bind;
          },
          SCALARREF => sub {  # literal SQL without bind
          },
          SCALAR_or_UNDEF => sub {
            push @all_bind, $self->_bindtype($k, $v);
          },
        });
    }

    return @all_bind;
}

sub generate {
    my $self  = shift;

    my(@sql, @sqlq, @sqlv);

    for (@_) {
        my $ref = ref $_;
        if ($ref eq 'HASH') {
            for my $k (sort keys %$_) {
                my $v = $_->{$k};
                my $r = ref $v;
                my $label = $self->_quote($k);
                if ($r eq 'ARRAY') {
                    # literal SQL with bind
                    my ($sql, @bind) = @$v;
                    $self->_assert_bindval_matches_bindtype(@bind);
                    push @sqlq, "$label = $sql";
                    push @sqlv, @bind;
                } elsif ($r eq 'SCALAR') {
                    # literal SQL without bind
                    push @sqlq, "$label = $$v";
                } else {
                    push @sqlq, "$label = ?";
                    push @sqlv, $self->_bindtype($k, $v);
                }
            }
            push @sql, $self->_sqlcase('set'), join ', ', @sqlq;
        } elsif ($ref eq 'ARRAY') {
            # unlike insert(), assume these are ONLY the column names, i.e. for SQL
            for my $v (@$_) {
                my $r = ref $v;
                if ($r eq 'ARRAY') {   # literal SQL with bind
                    my ($sql, @bind) = @$v;
                    $self->_assert_bindval_matches_bindtype(@bind);
                    push @sqlq, $sql;
                    push @sqlv, @bind;
                } elsif ($r eq 'SCALAR') {  # literal SQL without bind
                    # embedded literal SQL
                    push @sqlq, $$v;
                } else {
                    push @sqlq, '?';
                    push @sqlv, $v;
                }
            }
            push @sql, '(' . join(', ', @sqlq) . ')';
        } elsif ($ref eq 'SCALAR') {
            # literal SQL
            push @sql, $$_;
        } else {
            # strings get case twiddled
            push @sql, $self->_sqlcase($_);
        }
    }

    my $sql = join ' ', @sql;

    # this is pretty tricky
    # if ask for an array, return ($stmt, @bind)
    # otherwise, s/?/shift @sqlv/ to put it inline
    if (wantarray) {
        return ($sql, @sqlv);
    } else {
        1 while $sql =~ s/\?/my $d = shift(@sqlv);
                             ref $d ? $d->[1] : $d/e;
        return $sql;
    }
}


sub DESTROY { 1 }

sub AUTOLOAD {
    # This allows us to check for a local, then _form, attr
    my $self = shift;
    my($name) = $AUTOLOAD =~ /.*::(.+)/;
    return $self->generate($name, @_);
}

1;



__END__

=head1 NAME

SQL::Abstract - Generate SQL from Perl data structures

=head1 SYNOPSIS

    use SQL::Abstract;

    my $sql = SQL::Abstract->new;

    my($stmt, @bind) = $sql->select($source, \@fields, \%where, \@order);

    my($stmt, @bind) = $sql->insert($table, \%fieldvals || \@values);

    my($stmt, @bind) = $sql->update($table, \%fieldvals, \%where);

    my($stmt, @bind) = $sql->delete($table, \%where);

    # Then, use these in your DBI statements
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

    # Just generate the WHERE clause
    my($stmt, @bind) = $sql->where(\%where, \@order);

    # Return values in the same order, for hashed queries
    # See PERFORMANCE section for more details
    my @bind = $sql->values(\%fieldvals);

=head1 DESCRIPTION

This module was inspired by the excellent L<DBIx::Abstract>.
However, in using that module I found that what I really wanted
to do was generate SQL, but still retain complete control over my
statement handles and use the DBI interface. So, I set out to
create an abstract SQL generation module.

While based on the concepts used by L<DBIx::Abstract>, there are
several important differences, especially when it comes to WHERE
clauses. I have modified the concepts used to make the SQL easier
to generate from Perl data structures and, IMO, more intuitive.
The underlying idea is for this module to do what you mean, based
on the data structures you provide it. The big advantage is that
you don't have to modify your code every time your data changes,
as this module figures it out.

To begin with, an SQL INSERT is as easy as just specifying a hash
of C<key=value> pairs:

    my %data = (
        name => 'Jimbo Bobson',
        phone => '123-456-7890',
        address => '42 Sister Lane',
        city => 'St. Louis',
        state => 'Louisiana',
    );

The SQL can then be generated with this:

    my($stmt, @bind) = $sql->insert('people', \%data);

Which would give you something like this:

    $stmt = "INSERT INTO people
                    (address, city, name, phone, state)
                    VALUES (?, ?, ?, ?, ?)";
    @bind = ('42 Sister Lane', 'St. Louis', 'Jimbo Bobson',
             '123-456-7890', 'Louisiana');

These are then used directly in your DBI code:

    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

=head2 Inserting and Updating Arrays

If your database has array types (like for example Postgres),
activate the special option C<< array_datatypes => 1 >>
when creating the C<SQL::Abstract> object.
Then you may use an arrayref to insert and update database array types:

    my $sql = SQL::Abstract->new(array_datatypes => 1);
    my %data = (
        planets => [qw/Mercury Venus Earth Mars/]
    );

    my($stmt, @bind) = $sql->insert('solar_system', \%data);

This results in:

    $stmt = "INSERT INTO solar_system (planets) VALUES (?)"

    @bind = (['Mercury', 'Venus', 'Earth', 'Mars']);


=head2 Inserting and Updating SQL

In order to apply SQL functions to elements of your C<%data> you may
specify a reference to an arrayref for the given hash value. For example,
if you need to execute the Oracle C<to_date> function on a value, you can
say something like this:

    my %data = (
        name => 'Bill',
        date_entered => \["to_date(?,'MM/DD/YYYY')", "03/02/2003"],
    );

The first value in the array is the actual SQL. Any other values are
optional and would be included in the bind values array. This gives
you:

    my($stmt, @bind) = $sql->insert('people', \%data);

    $stmt = "INSERT INTO people (name, date_entered)
                VALUES (?, to_date(?,'MM/DD/YYYY'))";
    @bind = ('Bill', '03/02/2003');

An UPDATE is just as easy, all you change is the name of the function:

    my($stmt, @bind) = $sql->update('people', \%data);

Notice that your C<%data> isn't touched; the module will generate
the appropriately quirky SQL for you automatically. Usually you'll
want to specify a WHERE clause for your UPDATE, though, which is
where handling C<%where> hashes comes in handy...

=head2 Complex where statements

This module can generate pretty complicated WHERE statements
easily. For example, simple C<key=value> pairs are taken to mean
equality, and if you want to see if a field is within a set
of values, you can use an arrayref. Let's say we wanted to
SELECT some data based on this criteria:

    my %where = (
       requestor => 'inna',
       worker => ['nwiger', 'rcwe', 'sfz'],
       status => { '!=', 'completed' }
    );

    my($stmt, @bind) = $sql->select('tickets', '*', \%where);

The above would give you something like this:

    $stmt = "SELECT * FROM tickets WHERE
                ( requestor = ? ) AND ( status != ? )
                AND ( worker = ? OR worker = ? OR worker = ? )";
    @bind = ('inna', 'completed', 'nwiger', 'rcwe', 'sfz');

Which you could then use in DBI code like so:

    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

Easy, eh?

=head1 FUNCTIONS

The functions are simple. There's one for each major SQL operation,
and a constructor you use first. The arguments are specified in a
similar order to each function (table, then fields, then a where
clause) to try and simplify things.




=head2 new(option => 'value')

The C<new()> function takes a list of options and values, and returns
a new B<SQL::Abstract> object which can then be used to generate SQL
through the methods below. The options accepted are:

=over

=item case

If set to 'lower', then SQL will be generated in all lowercase. By
default SQL is generated in "textbook" case meaning something like:

    SELECT a_field FROM a_table WHERE some_field LIKE '%someval%'

Any setting other than 'lower' is ignored.

=item cmp

This determines what the default comparison operator is. By default
it is C<=>, meaning that a hash like this:

    %where = (name => 'nwiger', email => 'nate@wiger.org');

Will generate SQL like this:

    WHERE name = 'nwiger' AND email = 'nate@wiger.org'

However, you may want loose comparisons by default, so if you set
C<cmp> to C<like> you would get SQL such as:

    WHERE name like 'nwiger' AND email like 'nate@wiger.org'

You can also override the comparison on an individual basis - see
the huge section on L</"WHERE CLAUSES"> at the bottom.

=item sqltrue, sqlfalse

Expressions for inserting boolean values within SQL statements.
By default these are C<1=1> and C<1=0>. They are used
by the special operators C<-in> and C<-not_in> for generating
correct SQL even when the argument is an empty array (see below).

=item logic

This determines the default logical operator for multiple WHERE
statements in arrays or hashes. If absent, the default logic is "or"
for arrays, and "and" for hashes. This means that a WHERE
array of the form:

    @where = (
        event_date => {'>=', '2/13/99'},
        event_date => {'<=', '4/24/03'},
    );

will generate SQL like this:

    WHERE event_date >= '2/13/99' OR event_date <= '4/24/03'

This is probably not what you want given this query, though (look
at the dates). To change the "OR" to an "AND", simply specify:

    my $sql = SQL::Abstract->new(logic => 'and');

Which will change the above C<WHERE> to:

    WHERE event_date >= '2/13/99' AND event_date <= '4/24/03'

The logic can also be changed locally by inserting
a modifier in front of an arrayref :

    @where = (-and => [event_date => {'>=', '2/13/99'},
                       event_date => {'<=', '4/24/03'} ]);

See the L</"WHERE CLAUSES"> section for explanations.

=item convert

This will automatically convert comparisons using the specified SQL
function for both column and value. This is mostly used with an argument
of C<upper> or C<lower>, so that the SQL will have the effect of
case-insensitive "searches". For example, this:

    $sql = SQL::Abstract->new(convert => 'upper');
    %where = (keywords => 'MaKe iT CAse inSeNSItive');

Will turn out the following SQL:

    WHERE upper(keywords) like upper('MaKe iT CAse inSeNSItive')

The conversion can be C<upper()>, C<lower()>, or any other SQL function
that can be applied symmetrically to fields (actually B<SQL::Abstract> does
not validate this option; it will just pass through what you specify verbatim).

=item bindtype

This is a kludge because many databases suck. For example, you can't
just bind values using DBI's C<execute()> for Oracle C<CLOB> or C<BLOB> fields.
Instead, you have to use C<bind_param()>:

    $sth->bind_param(1, 'reg data');
    $sth->bind_param(2, $lots, {ora_type => ORA_CLOB});

The problem is, B<SQL::Abstract> will normally just return a C<@bind> array,
which loses track of which field each slot refers to. Fear not.

If you specify C<bindtype> in new, you can determine how C<@bind> is returned.
Currently, you can specify either C<normal> (default) or C<columns>. If you
specify C<columns>, you will get an array that looks like this:

    my $sql = SQL::Abstract->new(bindtype => 'columns');
    my($stmt, @bind) = $sql->insert(...);

    @bind = (
        [ 'column1', 'value1' ],
        [ 'column2', 'value2' ],
        [ 'column3', 'value3' ],
    );

You can then iterate through this manually, using DBI's C<bind_param()>.

    $sth->prepare($stmt);
    my $i = 1;
    for (@bind) {
        my($col, $data) = @$_;
        if ($col eq 'details' || $col eq 'comments') {
            $sth->bind_param($i, $data, {ora_type => ORA_CLOB});
        } elsif ($col eq 'image') {
            $sth->bind_param($i, $data, {ora_type => ORA_BLOB});
        } else {
            $sth->bind_param($i, $data);
        }
        $i++;
    }
    $sth->execute;      # execute without @bind now

Now, why would you still use B<SQL::Abstract> if you have to do this crap?
Basically, the advantage is still that you don't have to care which fields
are or are not included. You could wrap that above C<for> loop in a simple
sub called C<bind_fields()> or something and reuse it repeatedly. You still
get a layer of abstraction over manual SQL specification.

Note that if you set L</bindtype> to C<columns>, the C<\[$sql, @bind]>
construct (see L</Literal SQL with placeholders and bind values (subqueries)>)
will expect the bind values in this format.

=item quote_char

This is the character that a table or column name will be quoted
with.  By default this is an empty string, but you could set it to
the character C<`>, to generate SQL like this:

  SELECT `a_field` FROM `a_table` WHERE `some_field` LIKE '%someval%'

Alternatively, you can supply an array ref of two items, the first being the left
hand quote character, and the second the right hand quote character. For
example, you could supply C<['[',']']> for SQL Server 2000 compliant quotes
that generates SQL like this:

  SELECT [a_field] FROM [a_table] WHERE [some_field] LIKE '%someval%'

Quoting is useful if you have tables or columns names that are reserved
words in your database's SQL dialect.

=item name_sep

This is the character that separates a table and column name.  It is
necessary to specify this when the C<quote_char> option is selected,
so that tables and column names can be individually quoted like this:

  SELECT `table`.`one_field` FROM `table` WHERE `table`.`other_field` = 1

=item injection_guard

A regular expression C<qr/.../> that is applied to any C<-function> and unquoted
column name specified in a query structure. This is a safety mechanism to avoid
injection attacks when mishandling user input e.g.:

  my %condition_as_column_value_pairs = get_values_from_user();
  $sqla->select( ... , \%condition_as_column_value_pairs );

If the expression matches an exception is thrown. Note that literal SQL
supplied via C<\'...'> or C<\['...']> is B<not> checked in any way.

Defaults to checking for C<;> and the C<GO> keyword (TransactSQL)

=item array_datatypes

When this option is true, arrayrefs in INSERT or UPDATE are
interpreted as array datatypes and are passed directly
to the DBI layer.
When this option is false, arrayrefs are interpreted
as literal SQL, just like refs to arrayrefs
(but this behavior is for backwards compatibility; when writing
new queries, use the "reference to arrayref" syntax
for literal SQL).


=item special_ops

Takes a reference to a list of "special operators"
to extend the syntax understood by L<SQL::Abstract>.
See section L</"SPECIAL OPERATORS"> for details.

=item unary_ops

Takes a reference to a list of "unary operators"
to extend the syntax understood by L<SQL::Abstract>.
See section L</"UNARY OPERATORS"> for details.



=back

=head2 insert($table, \@values || \%fieldvals, \%options)

This is the simplest function. You simply give it a table name
and either an arrayref of values or hashref of field/value pairs.
It returns an SQL INSERT statement and a list of bind values.
See the sections on L</"Inserting and Updating Arrays"> and
L</"Inserting and Updating SQL"> for information on how to insert
with those data types.

The optional C<\%options> hash reference may contain additional
options to generate the insert SQL. Currently supported options
are:

=over 4

=item returning

Takes either a scalar of raw SQL fields, or an array reference of
field names, and adds on an SQL C<RETURNING> statement at the end.
This allows you to return data generated by the insert statement
(such as row IDs) without performing another C<SELECT> statement.
Note, however, this is not part of the SQL standard and may not
be supported by all database engines.

=back

=head2 update($table, \%fieldvals, \%where)

This takes a table, hashref of field/value pairs, and an optional
hashref L<WHERE clause|/WHERE CLAUSES>. It returns an SQL UPDATE function and a list
of bind values.
See the sections on L</"Inserting and Updating Arrays"> and
L</"Inserting and Updating SQL"> for information on how to insert
with those data types.

=head2 select($source, $fields, $where, $order)

This returns a SQL SELECT statement and associated list of bind values, as
specified by the arguments  :

=over

=item $source

Specification of the 'FROM' part of the statement.
The argument can be either a plain scalar (interpreted as a table
name, will be quoted), or an arrayref (interpreted as a list
of table names, joined by commas, quoted), or a scalarref
(literal table name, not quoted), or a ref to an arrayref
(list of literal table names, joined by commas, not quoted).

=item $fields

Specification of the list of fields to retrieve from
the source.
The argument can be either an arrayref (interpreted as a list
of field names, will be joined by commas and quoted), or a
plain scalar (literal SQL, not quoted).
Please observe that this API is not as flexible as that of
the first argument C<$source>, for backwards compatibility reasons.

=item $where

Optional argument to specify the WHERE part of the query.
The argument is most often a hashref, but can also be
an arrayref or plain scalar --
see section L<WHERE clause|/"WHERE CLAUSES"> for details.

=item $order

Optional argument to specify the ORDER BY part of the query.
The argument can be a scalar, a hashref or an arrayref
-- see section L<ORDER BY clause|/"ORDER BY CLAUSES">
for details.

=back


=head2 delete($table, \%where)

This takes a table name and optional hashref L<WHERE clause|/WHERE CLAUSES>.
It returns an SQL DELETE statement and list of bind values.

=head2 where(\%where, \@order)

This is used to generate just the WHERE clause. For example,
if you have an arbitrary data structure and know what the
rest of your SQL is going to look like, but want an easy way
to produce a WHERE clause, use this. It returns an SQL WHERE
clause and list of bind values.


=head2 values(\%data)

This just returns the values from the hash C<%data>, in the same
order that would be returned from any of the other above queries.
Using this allows you to markedly speed up your queries if you
are affecting lots of rows. See below under the L</"PERFORMANCE"> section.

=head2 generate($any, 'number', $of, \@data, $struct, \%types)

Warning: This is an experimental method and subject to change.

This returns arbitrarily generated SQL. It's a really basic shortcut.
It will return two different things, depending on return context:

    my($stmt, @bind) = $sql->generate('create table', \$table, \@fields);
    my $stmt_and_val = $sql->generate('create table', \$table, \@fields);

These would return the following:

    # First calling form
    $stmt = "CREATE TABLE test (?, ?)";
    @bind = (field1, field2);

    # Second calling form
    $stmt_and_val = "CREATE TABLE test (field1, field2)";

Depending on what you're trying to do, it's up to you to choose the correct
format. In this example, the second form is what you would want.

By the same token:

    $sql->generate('alter session', { nls_date_format => 'MM/YY' });

Might give you:

    ALTER SESSION SET nls_date_format = 'MM/YY'

You get the idea. Strings get their case twiddled, but everything
else remains verbatim.

=head1 WHERE CLAUSES

=head2 Introduction

This module uses a variation on the idea from L<DBIx::Abstract>. It
is B<NOT>, repeat I<not> 100% compatible. B<The main logic of this
module is that things in arrays are OR'ed, and things in hashes
are AND'ed.>

The easiest way to explain is to show lots of examples. After
each C<%where> hash shown, it is assumed you used:

    my($stmt, @bind) = $sql->where(\%where);

However, note that the C<%where> hash can be used directly in any
of the other functions as well, as described above.

=head2 Key-value pairs

So, let's get started. To begin, a simple hash:

    my %where  = (
        user   => 'nwiger',
        status => 'completed'
    );

Is converted to SQL C<key = val> statements:

    $stmt = "WHERE user = ? AND status = ?";
    @bind = ('nwiger', 'completed');

One common thing I end up doing is having a list of values that
a field can be in. To do this, simply specify a list inside of
an arrayref:

    my %where  = (
        user   => 'nwiger',
        status => ['assigned', 'in-progress', 'pending'];
    );

This simple code will create the following:

    $stmt = "WHERE user = ? AND ( status = ? OR status = ? OR status = ? )";
    @bind = ('nwiger', 'assigned', 'in-progress', 'pending');

A field associated to an empty arrayref will be considered a
logical false and will generate 0=1.

=head2 Tests for NULL values

If the value part is C<undef> then this is converted to SQL <IS NULL>

    my %where  = (
        user   => 'nwiger',
        status => undef,
    );

becomes:

    $stmt = "WHERE user = ? AND status IS NULL";
    @bind = ('nwiger');

To test if a column IS NOT NULL:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', undef },
    );

=head2 Specific comparison operators

If you want to specify a different type of operator for your comparison,
you can use a hashref for a given column:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', 'completed' }
    );

Which would generate:

    $stmt = "WHERE user = ? AND status != ?";
    @bind = ('nwiger', 'completed');

To test against multiple values, just enclose the values in an arrayref:

    status => { '=', ['assigned', 'in-progress', 'pending'] };

Which would give you:

    "WHERE status = ? OR status = ? OR status = ?"


The hashref can also contain multiple pairs, in which case it is expanded
into an C<AND> of its elements:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', 'completed', -not_like => 'pending%' }
    );

    # Or more dynamically, like from a form
    $where{user} = 'nwiger';
    $where{status}{'!='} = 'completed';
    $where{status}{'-not_like'} = 'pending%';

    # Both generate this
    $stmt = "WHERE user = ? AND status != ? AND status NOT LIKE ?";
    @bind = ('nwiger', 'completed', 'pending%');


To get an OR instead, you can combine it with the arrayref idea:

    my %where => (
         user => 'nwiger',
         priority => [ { '=', 2 }, { '>', 5 } ]
    );

Which would generate:

    $stmt = "WHERE ( priority = ? OR priority > ? ) AND user = ?";
    @bind = ('2', '5', 'nwiger');

If you want to include literal SQL (with or without bind values), just use a
scalar reference or array reference as the value:

    my %where  = (
        date_entered => { '>' => \["to_date(?, 'MM/DD/YYYY')", "11/26/2008"] },
        date_expires => { '<' => \"now()" }
    );

Which would generate:

    $stmt = "WHERE date_entered > "to_date(?, 'MM/DD/YYYY') AND date_expires < now()";
    @bind = ('11/26/2008');


=head2 Logic and nesting operators

In the example above,
there is a subtle trap if you want to say something like
this (notice the C<AND>):

    WHERE priority != ? AND priority != ?

Because, in Perl you I<can't> do this:

    priority => { '!=', 2, '!=', 1 }

As the second C<!=> key will obliterate the first. The solution
is to use the special C<-modifier> form inside an arrayref:

    priority => [ -and => {'!=', 2},
                          {'!=', 1} ]


Normally, these would be joined by C<OR>, but the modifier tells it
to use C<AND> instead. (Hint: You can use this in conjunction with the
C<logic> option to C<new()> in order to change the way your queries
work by default.) B<Important:> Note that the C<-modifier> goes
B<INSIDE> the arrayref, as an extra first element. This will
B<NOT> do what you think it might:

    priority => -and => [{'!=', 2}, {'!=', 1}]   # WRONG!

Here is a quick list of equivalencies, since there is some overlap:

    # Same
    status => {'!=', 'completed', 'not like', 'pending%' }
    status => [ -and => {'!=', 'completed'}, {'not like', 'pending%'}]

    # Same
    status => {'=', ['assigned', 'in-progress']}
    status => [ -or => {'=', 'assigned'}, {'=', 'in-progress'}]
    status => [ {'=', 'assigned'}, {'=', 'in-progress'} ]



=head2 Special operators : IN, BETWEEN, etc.

You can also use the hashref format to compare a list of fields using the
C<IN> comparison operator, by specifying the list as an arrayref:

    my %where  = (
        status   => 'completed',
        reportid => { -in => [567, 2335, 2] }
    );

Which would generate:

    $stmt = "WHERE status = ? AND reportid IN (?,?,?)";
    @bind = ('completed', '567', '2335', '2');

The reverse operator C<-not_in> generates SQL C<NOT IN> and is used in
the same way.

If the argument to C<-in> is an empty array, 'sqlfalse' is generated
(by default : C<1=0>). Similarly, C<< -not_in => [] >> generates
'sqltrue' (by default : C<1=1>).

In addition to the array you can supply a chunk of literal sql or
literal sql with bind:

    my %where = {
      customer => { -in => \[
        'SELECT cust_id FROM cust WHERE balance > ?',
        2000,
      ],
      status => { -in => \'SELECT status_codes FROM states' },
    };

would generate:

    $stmt = "WHERE (
          customer IN ( SELECT cust_id FROM cust WHERE balance > ? )
      AND status IN ( SELECT status_codes FROM states )
    )";
    @bind = ('2000');

Finally, if the argument to C<-in> is not a reference, it will be
treated as a single-element array.

Another pair of operators is C<-between> and C<-not_between>,
used with an arrayref of two values:

    my %where  = (
        user   => 'nwiger',
        completion_date => {
           -not_between => ['2002-10-01', '2003-02-06']
        }
    );

Would give you:

    WHERE user = ? AND completion_date NOT BETWEEN ( ? AND ? )

Just like with C<-in> all plausible combinations of literal SQL
are possible:

    my %where = {
      start0 => { -between => [ 1, 2 ] },
      start1 => { -between => \["? AND ?", 1, 2] },
      start2 => { -between => \"lower(x) AND upper(y)" },
      start3 => { -between => [
        \"lower(x)",
        \["upper(?)", 'stuff' ],
      ] },
    };

Would give you:

    $stmt = "WHERE (
          ( start0 BETWEEN ? AND ?                )
      AND ( start1 BETWEEN ? AND ?                )
      AND ( start2 BETWEEN lower(x) AND upper(y)  )
      AND ( start3 BETWEEN lower(x) AND upper(?)  )
    )";
    @bind = (1, 2, 1, 2, 'stuff');


These are the two builtin "special operators"; but the
list can be expanded : see section L</"SPECIAL OPERATORS"> below.

=head2 Unary operators: bool

If you wish to test against boolean columns or functions within your
database you can use the C<-bool> and C<-not_bool> operators. For
example to test the column C<is_user> being true and the column
C<is_enabled> being false you would use:-

    my %where  = (
        -bool       => 'is_user',
        -not_bool   => 'is_enabled',
    );

Would give you:

    WHERE is_user AND NOT is_enabled

If a more complex combination is required, testing more conditions,
then you should use the and/or operators:-

    my %where  = (
        -and           => [
            -bool      => 'one',
            -not_bool  => { two=> { -rlike => 'bar' } },
            -not_bool  => { three => [ { '=', 2 }, { '>', 5 } ] },
        ],
    );

Would give you:

    WHERE
      one
        AND
      (NOT two RLIKE ?)
        AND
      (NOT ( three = ? OR three > ? ))


=head2 Nested conditions, -and/-or prefixes

So far, we've seen how multiple conditions are joined with a top-level
C<AND>.  We can change this by putting the different conditions we want in
hashes and then putting those hashes in an array. For example:

    my @where = (
        {
            user   => 'nwiger',
            status => { -like => ['pending%', 'dispatched'] },
        },
        {
            user   => 'robot',
            status => 'unassigned',
        }
    );

This data structure would create the following:

    $stmt = "WHERE ( user = ? AND ( status LIKE ? OR status LIKE ? ) )
                OR ( user = ? AND status = ? ) )";
    @bind = ('nwiger', 'pending', 'dispatched', 'robot', 'unassigned');


Clauses in hashrefs or arrayrefs can be prefixed with an C<-and> or C<-or>
to change the logic inside :

    my @where = (
         -and => [
            user => 'nwiger',
            [
                -and => [ workhrs => {'>', 20}, geo => 'ASIA' ],
                -or => { workhrs => {'<', 50}, geo => 'EURO' },
            ],
        ],
    );

That would yield:

    WHERE ( user = ? AND (
               ( workhrs > ? AND geo = ? )
            OR ( workhrs < ? OR geo = ? )
          ) )

=head3 Algebraic inconsistency, for historical reasons

C<Important note>: when connecting several conditions, the C<-and->|C<-or>
operator goes C<outside> of the nested structure; whereas when connecting
several constraints on one column, the C<-and> operator goes
C<inside> the arrayref. Here is an example combining both features :

   my @where = (
     -and => [a => 1, b => 2],
     -or  => [c => 3, d => 4],
      e   => [-and => {-like => 'foo%'}, {-like => '%bar'} ]
   )

yielding

  WHERE ( (    ( a = ? AND b = ? )
            OR ( c = ? OR d = ? )
            OR ( e LIKE ? AND e LIKE ? ) ) )

This difference in syntax is unfortunate but must be preserved for
historical reasons. So be careful : the two examples below would
seem algebraically equivalent, but they are not

  {col => [-and => {-like => 'foo%'}, {-like => '%bar'}]}
  # yields : WHERE ( ( col LIKE ? AND col LIKE ? ) )

  [-and => {col => {-like => 'foo%'}, {col => {-like => '%bar'}}]]
  # yields : WHERE ( ( col LIKE ? OR col LIKE ? ) )


=head2 Literal SQL and value type operators

The basic premise of SQL::Abstract is that in WHERE specifications the "left
side" is a column name and the "right side" is a value (normally rendered as
a placeholder). This holds true for both hashrefs and arrayref pairs as you
see in the L</WHERE CLAUSES> examples above. Sometimes it is necessary to
alter this behavior. There are several ways of doing so.

=head3 -ident

This is a virtual operator that signals the string to its right side is an
identifier (a column name) and not a value. For example to compare two
columns you would write:

    my %where = (
        priority => { '<', 2 },
        requestor => { -ident => 'submitter' },
    );

which creates:

    $stmt = "WHERE priority < ? AND requestor = submitter";
    @bind = ('2');

If you are maintaining legacy code you may see a different construct as
described in L</Deprecated usage of Literal SQL>, please use C<-ident> in new
code.

=head3 -value

This is a virtual operator that signals that the construct to its right side
is a value to be passed to DBI. This is for example necessary when you want
to write a where clause against an array (for RDBMS that support such
datatypes). For example:

    my %where = (
        array => { -value => [1, 2, 3] }
    );

will result in:

    $stmt = 'WHERE array = ?';
    @bind = ([1, 2, 3]);

Note that if you were to simply say:

    my %where = (
        array => [1, 2, 3]
    );

the result would probably not be what you wanted:

    $stmt = 'WHERE array = ? OR array = ? OR array = ?';
    @bind = (1, 2, 3);

=head3 Literal SQL

Finally, sometimes only literal SQL will do. To include a random snippet
of SQL verbatim, you specify it as a scalar reference. Consider this only
as a last resort. Usually there is a better way. For example:

    my %where = (
        priority => { '<', 2 },
        requestor => { -in => \'(SELECT name FROM hitmen)' },
    );

Would create:

    $stmt = "WHERE priority < ? AND requestor IN (SELECT name FROM hitmen)"
    @bind = (2);

Note that in this example, you only get one bind parameter back, since
the verbatim SQL is passed as part of the statement.

=head4 CAVEAT

  Never use untrusted input as a literal SQL argument - this is a massive
  security risk (there is no way to check literal snippets for SQL
  injections and other nastyness). If you need to deal with untrusted input
  use literal SQL with placeholders as described next.

=head3 Literal SQL with placeholders and bind values (subqueries)

If the literal SQL to be inserted has placeholders and bind values,
use a reference to an arrayref (yes this is a double reference --
not so common, but perfectly legal Perl). For example, to find a date
in Postgres you can use something like this:

    my %where = (
       date_column => \[q/= date '2008-09-30' - ?::integer/, 10/]
    )

This would create:

    $stmt = "WHERE ( date_column = date '2008-09-30' - ?::integer )"
    @bind = ('10');

Note that you must pass the bind values in the same format as they are returned
by L</where>. That means that if you set L</bindtype> to C<columns>, you must
provide the bind values in the C<< [ column_meta => value ] >> format, where
C<column_meta> is an opaque scalar value; most commonly the column name, but
you can use any scalar value (including references and blessed references),
L<SQL::Abstract> will simply pass it through intact. So if C<bindtype> is set
to C<columns> the above example will look like:

    my %where = (
       date_column => \[q/= date '2008-09-30' - ?::integer/, [ dummy => 10 ]/]
    )

Literal SQL is especially useful for nesting parenthesized clauses in the
main SQL query. Here is a first example :

  my ($sub_stmt, @sub_bind) = ("SELECT c1 FROM t1 WHERE c2 < ? AND c3 LIKE ?",
                               100, "foo%");
  my %where = (
    foo => 1234,
    bar => \["IN ($sub_stmt)" => @sub_bind],
  );

This yields :

  $stmt = "WHERE (foo = ? AND bar IN (SELECT c1 FROM t1
                                             WHERE c2 < ? AND c3 LIKE ?))";
  @bind = (1234, 100, "foo%");

Other subquery operators, like for example C<"E<gt> ALL"> or C<"NOT IN">,
are expressed in the same way. Of course the C<$sub_stmt> and
its associated bind values can be generated through a former call
to C<select()> :

  my ($sub_stmt, @sub_bind)
     = $sql->select("t1", "c1", {c2 => {"<" => 100},
                                 c3 => {-like => "foo%"}});
  my %where = (
    foo => 1234,
    bar => \["> ALL ($sub_stmt)" => @sub_bind],
  );

In the examples above, the subquery was used as an operator on a column;
but the same principle also applies for a clause within the main C<%where>
hash, like an EXISTS subquery :

  my ($sub_stmt, @sub_bind)
     = $sql->select("t1", "*", {c1 => 1, c2 => \"> t0.c0"});
  my %where = ( -and => [
    foo   => 1234,
    \["EXISTS ($sub_stmt)" => @sub_bind],
  ]);

which yields

  $stmt = "WHERE (foo = ? AND EXISTS (SELECT * FROM t1
                                        WHERE c1 = ? AND c2 > t0.c0))";
  @bind = (1234, 1);


Observe that the condition on C<c2> in the subquery refers to
column C<t0.c0> of the main query : this is I<not> a bind
value, so we have to express it through a scalar ref.
Writing C<< c2 => {">" => "t0.c0"} >> would have generated
C<< c2 > ? >> with bind value C<"t0.c0"> ... not exactly
what we wanted here.

Finally, here is an example where a subquery is used
for expressing unary negation:

  my ($sub_stmt, @sub_bind)
     = $sql->where({age => [{"<" => 10}, {">" => 20}]});
  $sub_stmt =~ s/^ where //i; # don't want "WHERE" in the subclause
  my %where = (
        lname  => {like => '%son%'},
        \["NOT ($sub_stmt)" => @sub_bind],
    );

This yields

  $stmt = "lname LIKE ? AND NOT ( age < ? OR age > ? )"
  @bind = ('%son%', 10, 20)

=head3 Deprecated usage of Literal SQL

Below are some examples of archaic use of literal SQL. It is shown only as
reference for those who deal with legacy code. Each example has a much
better, cleaner and safer alternative that users should opt for in new code.

=over

=item *

    my %where = ( requestor => \'IS NOT NULL' )

    $stmt = "WHERE requestor IS NOT NULL"

This used to be the way of generating NULL comparisons, before the handling
of C<undef> got formalized. For new code please use the superior syntax as
described in L</Tests for NULL values>.

=item *

    my %where = ( requestor => \'= submitter' )

    $stmt = "WHERE requestor = submitter"

This used to be the only way to compare columns. Use the superior L</-ident>
method for all new code. For example an identifier declared in such a way
will be properly quoted if L</quote_char> is properly set, while the legacy
form will remain as supplied.

=item *

    my %where = ( is_ready  => \"", completed => { '>', '2012-12-21' } )

    $stmt = "WHERE completed > ? AND is_ready"
    @bind = ('2012-12-21')

Using an empty string literal used to be the only way to express a boolean.
For all new code please use the much more readable
L<-bool|/Unary operators: bool> operator.

=back

=head2 Conclusion

These pages could go on for a while, since the nesting of the data
structures this module can handle are pretty much unlimited (the
module implements the C<WHERE> expansion as a recursive function
internally). Your best bet is to "play around" with the module a
little to see how the data structures behave, and choose the best
format for your data based on that.

And of course, all the values above will probably be replaced with
variables gotten from forms or the command line. After all, if you
knew everything ahead of time, you wouldn't have to worry about
dynamically-generating SQL and could just hardwire it into your
script.

=head1 ORDER BY CLAUSES

Some functions take an order by clause. This can either be a scalar (just a
column name,) a hash of C<< { -desc => 'col' } >> or C<< { -asc => 'col' } >>,
or an array of either of the two previous forms. Examples:

               Given            |         Will Generate
    ----------------------------------------------------------
                                |
    \'colA DESC'                | ORDER BY colA DESC
                                |
    'colA'                      | ORDER BY colA
                                |
    [qw/colA colB/]             | ORDER BY colA, colB
                                |
    {-asc  => 'colA'}           | ORDER BY colA ASC
                                |
    {-desc => 'colB'}           | ORDER BY colB DESC
                                |
    ['colA', {-asc => 'colB'}]  | ORDER BY colA, colB ASC
                                |
    { -asc => [qw/colA colB/] } | ORDER BY colA ASC, colB ASC
                                |
    [                           |
      { -asc => 'colA' },       | ORDER BY colA ASC, colB DESC,
      { -desc => [qw/colB/],    |          colC ASC, colD ASC
      { -asc => [qw/colC colD/],|
    ]                           |
    ===========================================================



=head1 SPECIAL OPERATORS

  my $sqlmaker = SQL::Abstract->new(special_ops => [
     {
      regex => qr/.../,
      handler => sub {
        my ($self, $field, $op, $arg) = @_;
        ...
      },
     },
     {
      regex => qr/.../,
      handler => 'method_name',
     },
   ]);

A "special operator" is a SQL syntactic clause that can be
applied to a field, instead of a usual binary operator.
For example :

   WHERE field IN (?, ?, ?)
   WHERE field BETWEEN ? AND ?
   WHERE MATCH(field) AGAINST (?, ?)

Special operators IN and BETWEEN are fairly standard and therefore
are builtin within C<SQL::Abstract> (as the overridable methods
C<_where_field_IN> and C<_where_field_BETWEEN>). For other operators,
like the MATCH .. AGAINST example above which is specific to MySQL,
you can write your own operator handlers - supply a C<special_ops>
argument to the C<new> method. That argument takes an arrayref of
operator definitions; each operator definition is a hashref with two
entries:

=over

=item regex

the regular expression to match the operator

=item handler

Either a coderef or a plain scalar method name. In both cases
the expected return is C<< ($sql, @bind) >>.

When supplied with a method name, it is simply called on the
L<SQL::Abstract/> object as:

 $self->$method_name ($field, $op, $arg)

 Where:

  $op is the part that matched the handler regex
  $field is the LHS of the operator
  $arg is the RHS

When supplied with a coderef, it is called as:

 $coderef->($self, $field, $op, $arg)


=back

For example, here is an implementation
of the MATCH .. AGAINST syntax for MySQL

  my $sqlmaker = SQL::Abstract->new(special_ops => [

    # special op for MySql MATCH (field) AGAINST(word1, word2, ...)
    {regex => qr/^match$/i,
     handler => sub {
       my ($self, $field, $op, $arg) = @_;
       $arg = [$arg] if not ref $arg;
       my $label         = $self->_quote($field);
       my ($placeholder) = $self->_convert('?');
       my $placeholders  = join ", ", (($placeholder) x @$arg);
       my $sql           = $self->_sqlcase('match') . " ($label) "
                         . $self->_sqlcase('against') . " ($placeholders) ";
       my @bind = $self->_bindtype($field, @$arg);
       return ($sql, @bind);
       }
     },

  ]);


=head1 UNARY OPERATORS

  my $sqlmaker = SQL::Abstract->new(unary_ops => [
     {
      regex => qr/.../,
      handler => sub {
        my ($self, $op, $arg) = @_;
        ...
      },
     },
     {
      regex => qr/.../,
      handler => 'method_name',
     },
   ]);

A "unary operator" is a SQL syntactic clause that can be
applied to a field - the operator goes before the field

You can write your own operator handlers - supply a C<unary_ops>
argument to the C<new> method. That argument takes an arrayref of
operator definitions; each operator definition is a hashref with two
entries:

=over

=item regex

the regular expression to match the operator

=item handler

Either a coderef or a plain scalar method name. In both cases
the expected return is C<< $sql >>.

When supplied with a method name, it is simply called on the
L<SQL::Abstract/> object as:

 $self->$method_name ($op, $arg)

 Where:

  $op is the part that matched the handler regex
  $arg is the RHS or argument of the operator

When supplied with a coderef, it is called as:

 $coderef->($self, $op, $arg)


=back


=head1 PERFORMANCE

Thanks to some benchmarking by Mark Stosberg, it turns out that
this module is many orders of magnitude faster than using C<DBIx::Abstract>.
I must admit this wasn't an intentional design issue, but it's a
byproduct of the fact that you get to control your C<DBI> handles
yourself.

To maximize performance, use a code snippet like the following:

    # prepare a statement handle using the first row
    # and then reuse it for the rest of the rows
    my($sth, $stmt);
    for my $href (@array_of_hashrefs) {
        $stmt ||= $sql->insert('table', $href);
        $sth  ||= $dbh->prepare($stmt);
        $sth->execute($sql->values($href));
    }

The reason this works is because the keys in your C<$href> are sorted
internally by B<SQL::Abstract>. Thus, as long as your data retains
the same structure, you only have to generate the SQL the first time
around. On subsequent queries, simply use the C<values> function provided
by this module to return your values in the correct order.

However this depends on the values having the same type - if, for
example, the values of a where clause may either have values
(resulting in sql of the form C<column = ?> with a single bind
value), or alternatively the values might be C<undef> (resulting in
sql of the form C<column IS NULL> with no bind value) then the
caching technique suggested will not work.

=head1 FORMBUILDER

If you use my C<CGI::FormBuilder> module at all, you'll hopefully
really like this part (I do, at least). Building up a complex query
can be as simple as the following:

    #!/usr/bin/perl

    use warnings;
    use strict;

    use CGI::FormBuilder;
    use SQL::Abstract;

    my $form = CGI::FormBuilder->new(...);
    my $sql  = SQL::Abstract->new;

    if ($form->submitted) {
        my $field = $form->field;
        my $id = delete $field->{id};
        my($stmt, @bind) = $sql->update('table', $field, {id => $id});
    }

Of course, you would still have to connect using C<DBI> to run the
query, but the point is that if you make your form look like your
table, the actual query script can be extremely simplistic.

If you're B<REALLY> lazy (I am), check out C<HTML::QuickTable> for
a fast interface to returning and formatting data. I frequently
use these three modules together to write complex database query
apps in under 50 lines.

=head1 REPO

=over

=item * gitweb: L<http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=dbsrgits/SQL-Abstract.git>

=item * git: L<git://git.shadowcat.co.uk/dbsrgits/SQL-Abstract.git>

=back

=head1 CHANGES

Version 1.50 was a major internal refactoring of C<SQL::Abstract>.
Great care has been taken to preserve the I<published> behavior
documented in previous versions in the 1.* family; however,
some features that were previously undocumented, or behaved
differently from the documentation, had to be changed in order
to clarify the semantics. Hence, client code that was relying
on some dark areas of C<SQL::Abstract> v1.*
B<might behave differently> in v1.50.

The main changes are :

=over

=item *

support for literal SQL through the C<< \ [$sql, bind] >> syntax.

=item *

support for the { operator => \"..." } construct (to embed literal SQL)

=item *

support for the { operator => \["...", @bind] } construct (to embed literal SQL with bind values)

=item *

optional support for L<array datatypes|/"Inserting and Updating Arrays">

=item *

defensive programming : check arguments

=item *

fixed bug with global logic, which was previously implemented
through global variables yielding side-effects. Prior versions would
interpret C<< [ {cond1, cond2}, [cond3, cond4] ] >>
as C<< "(cond1 AND cond2) OR (cond3 AND cond4)" >>.
Now this is interpreted
as C<< "(cond1 AND cond2) OR (cond3 OR cond4)" >>.


=item *

fixed semantics of  _bindtype on array args

=item *

dropped the C<_anoncopy> of the %where tree. No longer necessary,
we just avoid shifting arrays within that tree.

=item *

dropped the C<_modlogic> function

=back

=head1 ACKNOWLEDGEMENTS

There are a number of individuals that have really helped out with
this module. Unfortunately, most of them submitted bugs via CPAN
so I have no idea who they are! But the people I do know are:

    Ash Berlin (order_by hash term support)
    Matt Trout (DBIx::Class support)
    Mark Stosberg (benchmarking)
    Chas Owens (initial "IN" operator support)
    Philip Collins (per-field SQL functions)
    Eric Kolve (hashref "AND" support)
    Mike Fragassi (enhancements to "BETWEEN" and "LIKE")
    Dan Kubb (support for "quote_char" and "name_sep")
    Guillermo Roditi (patch to cleanup "IN" and "BETWEEN", fix and tests for _order_by)
    Laurent Dami (internal refactoring, extensible list of special operators, literal SQL)
    Norbert Buchmuller (support for literal SQL in hashpair, misc. fixes & tests)
    Peter Rabbitson (rewrite of SQLA::Test, misc. fixes & tests)
    Oliver Charles (support for "RETURNING" after "INSERT")

Thanks!

=head1 SEE ALSO

L<DBIx::Class>, L<DBIx::Abstract>, L<CGI::FormBuilder>, L<HTML::QuickTable>.

=head1 AUTHOR

Copyright (c) 2001-2007 Nathan Wiger <nwiger@cpan.org>. All Rights Reserved.

This module is actively maintained by Matt Trout <mst@shadowcatsystems.co.uk>

For support, your best bet is to try the C<DBIx::Class> users mailing list.
While not an official support venue, C<DBIx::Class> makes heavy use of
C<SQL::Abstract>, and as such list members there are very familiar with
how to create queries.

=head1 LICENSE

This module is free software; you may copy this under the same
terms as perl itself (either the GNU General Public License or
the Artistic License)

=cut

