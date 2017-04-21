package File::Sticker::Writer;

=head1 NAME

File::Sticker::Writer - write and standardize meta-data from files

=head1 SYNOPSIS

    use File::Sticker::Writer;

    my $obj = File::Sticker::Writer->new(%args);

    my %meta = $obj->write_meta(%args);

=head1 DESCRIPTION

This will write meta-data from files in various formats, and standardize it to a common
nomenclature.

=cut

use common::sense;
use File::LibMagic;

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = File::Sticker::Writer->new();

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    return ($self);
} # new

=head2 init

Initialize the object.
Set which fields you are interested in ('wanted_fields').

    $writer->init(wanted_fields=>{title=>'TEXT',count=>'NUMBER',tags=>'MULTI'});

=cut

sub init {
    my $self = shift;
    my %parameters = @_;

    foreach my $key (keys %parameters)
    {
	$self->{$key} = $parameters{$key};
    }
    $self->{file_magic} = File::LibMagic->new();
} # init

=head2 name

The name of the writer; this is basically the last component
of the module name.  This works as either a class function or a method.

$name = $self->name();

$name = File::Sticker::Writer::name($class);

=cut

sub name {
    my $class = shift;
    
    my $fullname = (ref ($class) ? ref ($class) : $class);

    my @bits = split('::', $fullname);
    return pop @bits;
} # name

=head2 allow

If this writer can be used for the given file, and the wanted_fields then this returns true.
Returns false if there are no 'wanted_fields'!

    if ($writer->allow($file))
    {
	....
    }

=cut

sub allow {
    my $self = shift;
    my $file = shift;

    my $okay = $self->allowed_file($file);
    if ($okay) # okay so far
    {
        if (exists $self->{wanted_fields}
                and defined $self->{wanted_fields})
        {
            # the known fields must be a subset of the wanted fields
            my $known_fields = $self->known_fields();
            foreach my $fn (keys %{$self->{wanted_fields}})
            {
                if (!exists $known_fields->{$fn}
                        or !defined $known_fields->{$fn}
                        or !$known_fields->{$fn})
                {
                    $okay = 0;
                    last;
                }
            }
        }
        else
        {
            $okay = 0;
        }
    }
    return $okay;
} # allow

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
This must be overridden by the specific writer class.

    if ($writer->allowed_file($file))
    {
	....
    }

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this writer knows about.

This must be overridden by the specific writer class.

    my $known_fields = $writer->known_fields();

=cut

sub known_fields {
    my $self = shift;

    return undef;
} # known_fields

=head2 write_meta

Write the meta-data to the given file.

This must be overridden by the specific writer class.

    $writer->write_meta(filename=>$filename,meta=>\%meta);

=cut

sub write_meta {
    my $self = shift;
    my %args = @_;

} # write_meta

=head2 add_multival_to_file 

Add a multi-valued field to the file.
Needs to know the existing values of the multi-valued field.
The old values are either a reference to an array, or a string with comma-separated values.

    $writer->add_multival_to_file(filename=>$filename,
        value=>$value,
        field=>$field_name,
        old_vals=>$old_vals);

=cut
sub add_multival_to_file {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};
    my $tval = $args{value};
    my $fname = $args{field};
    my $old_vals = $args{old_vals};

    # add a new tval to existing taglike-values
    my %th = ();
    $th{$tval} = 1;

    my @old_values = ();
    if (ref $old_vals eq 'ARRAY')
    {
        @old_values = @{$old_vals};
    }
    elsif (!ref $old_vals)
    {
        @old_values = split(/,/, $old_vals);
    }
    foreach my $t (@old_values)
    {
        $th{$t} = 1;
    }
    my @newvals = keys %th;
    @newvals = sort @newvals;
    my $newvals = join(',', @newvals);

    $self->replace_one_field(filename=>$filename,
        field=>$fname,
        value=>$newvals);
} # add_multival_to_file

=head2 delete_multival_from_file

Remove one value of a multi-valued field.
Needs to know the existing values of the multi-valued field.
The old values are either a reference to an array, or a string with comma-separated values.

    $writer->delete_multival_from_file(filename=>$filename,
        value=>$value,
        field=>$field_name,
        old_vals=>$old_vals);

=cut
sub delete_multival_from_file ($%) {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};
    my $tval = $args{value};
    my $fname = $args{field};
    my $old_vals = $args{old_vals};

    # remove value from existing values
    my %th = ();

    my @old_values = ();
    if (ref $old_vals eq 'ARRAY')
    {
        @old_values = @{$old_vals};
    }
    elsif (!ref $old_vals)
    {
        @old_values = split(/,/, $old_vals);
    }
    foreach my $t (@old_values)
    {
        if ($t ne $tval)
        {
            $th{$t} = 1;
        }
    }
    my @newvals = keys %th;
    @newvals = sort @newvals;
    my $newvals = join(',', @newvals);

    $self->replace_one_field(filename=>$filename,
        field=>$fname,
        value=>$newvals);
} # delete_multival_from_file

=head1 Helper Functions

Private interface.

=head2 replace_one_field

Overwrite the given field. This does no checking.

This must be overridden by the specific writer class.

    $writer->replace_one_field(filename=>$filename,field=>$field,value=>$value);

=cut

sub replace_one_field {
    my $self = shift;
    my %args = @_;
    my $filename = $args{filename};
    my $field = $args{field};
    my $value = $args{value};

} # replace_one_field

=head2 delete_one_field

Completely remove the given field. This does no checking.

This must be overridden by the specific writer class.

    $writer->delete_one_field(filename=>$filename,field=>$field);

=cut

sub delete_one_field {
    my $self = shift;
    my %args = @_;
    my $filename = $args{filename};
    my $field = $args{field};

} # delete_one_field

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
