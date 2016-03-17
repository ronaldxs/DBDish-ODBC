use v6;
need DBDish;

unit class DBDish::ODBC::StatementHandle does DBDish::StatementHandle;
use DBDish::ODBC::Native;
use NativeCall;

has SQLDBC $!conn is required;
has SQLSTMT $!sth is required;
has @!param-type;
has $!field_count;

submethod BUILD(:$!conn!, :$!parent!, :$!sth, :@!param-type, :$!RaiseError
) { }

method !handle-error($rep) {
    $rep ~~ ODBCErr ?? self!set-err(|$rep) !! $rep
}

method execute(*@params) {
    self!set-err(-1,
	"Wrong number of arguments to method execute: got @params.elems(), expected @!param-type.elems()"
    ) if @params != @!param-type;

    self!enter-execute;
    my @bufs;
    my Buf[int64] $SoI .= allocate(+@params);
    for @params.kv -> $k, $v {
	if $v.defined {
	    my $param = ($v ~~ Blob) ?? $v !! (~$v).encode;
	    @bufs.push($param);
	    $SoI[$k] = $param.bytes;
	    self!handle-error($!sth.BindParameter($k+1, @!param-type[$k], $param, $SoI));
	} else {
	    $SoI[$k] = SQL_NULL_DATA;
	    self!handle-error($!sth.BindParameter($k+1, @!param-type[$k], Buf, $SoI));
	}
    }
    without self!handle-error: $!sth.handle-res($!sth.Execute) { .fail }
    my $rows = $!sth.RowCount; my $was-select = True;
    without $!field_count {
	$!field_count = $!sth.NumResultCols;
	for ^$!field_count {
	    my $meta = $!sth.DescribeCol($_+1);
	    @!column-name.push($meta<name>);
	    @!column-type.push($meta<type>);
	}
	# TODO, not all ODBC drivers returns a sensible RowCount for SELECT
    }
    unless $!field_count {
	$was-select = False;
    }
    self!done-execute($rows, $was-select);
}

method _row(:$hash) {
    my @row_array;
    my %ret_hash;
    if $!field_count -> $cols {
	given $!sth.Fetch {
	    when SQL_SUCCESS {
		for ^$cols {
		    my $type = @!column-type[$_]; my $raw = $type ~~ Buf;
		    my $value = do with $!sth.GetData($_ + 1, :$raw) {
			$raw ?? $_ !! .$type
		    } else { $type }
		    $hash ?? (%ret_hash{@!column-name[$_]} = $value)
			  !! @row_array.push($value);
		}
	    }
	    when SQL_NO_DATA { self.finish }
	}
    }
    $hash ?? %ret_hash !! @row_array;

}

method fetchrow {
    my @results;
    if $!field_count -> $cols {
	given $!sth.Fetch {
	    when SQL_SUCCESS {
		@results[$_] = $!sth.GetData($_ + 1) // Str for ^$cols;
	    }
	    when SQL_NO_DATA { self.finish }
	}
    }
    @results;
}

method _free {
    with $!sth {
	.dispose;
	$_ = Nil;
    }
}

method finish {
    with $!sth {
	.CloseCursor if $!field_count;
    }
    $!Finished = True;
}
