package File::Sticker;

=head1 NAME

File::Sticker - Read, Write file meta-data

=head1 SYNOPSIS

    use File::Sticker;

    my $obj = File::Sticker->new(%args);

=head1 DESCRIPTION

This will read and write meta-data from files, in a standardized manner.
And update a database with that information.

=cut

use common::sense;
use File::Sticker::Reader;
use File::Sticker::Writer;
use File::Sticker::Database;
use Hash::Merge;
use YAML::Any;
use Module::Pluggable instantiate => 'new',
search_path => ['File::Sticker::Reader'],
sub_name => 'readers';
use Module::Pluggable instantiate => 'new',
search_path => ['File::Sticker::Writer'],
sub_name => 'writers';

# FOR DEBUGGING
sub whoami  { ( caller(1) )[3] }

=head1 METHODS

=head2 new

Create a new object, setting global values for the object.

    my $obj = File::Sticker->new(
        wanted_fields=>\%wanted_fields,
        verbose=>$verbose,
        dbname=>$dbname,
        field_order=>\@fields,
        primary_table=>$primary_table,
    );

=cut

sub new {
    my $class = shift;
    my %parameters = (@_);
    my $self = bless ({%parameters}, ref ($class) || $class);

    my %new_args = ();
    foreach my $key (qw(wanted_fields verbose))
    {
        if (exists $self->{$key})
        {
            $new_args{$key} = $self->{$key};
        }
    }
    # -------------------------------------
    # Readers
    my @readers = $self->readers();
    foreach my $rd (@readers)
    {
        print STDERR "READER: ", $rd->name(), "\n" if $self->{verbose} > 1;
	$rd->init(%new_args);
    }
    $self->{_readers} = \@readers;

    # -------------------------------------
    # Writers
    my @writers = $self->writers();
    foreach my $wt (@writers)
    {
        print STDERR "WRITER: ", $wt->name(), "\n" if $self->{verbose} > 1;
	$wt->init(%new_args);
    }
    $self->{_writers} = \@writers;

    # -------------------------------------
    # Database (optional)
    # -------------------------------------
    if (exists $self->{dbname}
            and exists $self->{wanted_fields}
            and exists $self->{field_order}
            and exists $self->{primary_table})
    {
        # we have enough to instantiate a database object
        $self->{db} = File::Sticker::Database->new(
            dbname=>$self->{dbname},
            wanted_fields=>$self->{wanted_fields},
            field_order=>$self->{field_order},
            primary_table=>$self->{primary_table},
        );
        $self->{db}->do_connect();
        $self->{db}->create_tables();
    }

    return ($self);
} # new

=head2 read_meta

This will read the meta-data from the file, using all possible ways.

    my $info = $fs->read_meta($filename);

=cut
sub read_meta ($%) {
    my $self = shift;
    my $filename = shift;
    say STDERR whoami(), " filename=$filename" if $self->{verbose} > 2;

    if (!-r $filename)
    {
        # the file may not exist yet, so don't die
        return {};
    }

    # Set the merge to RIGHT_PRECEDENT because
    # both Xattr and Yaml support more values
    # and they also both come at the end of the alphabet
    # so therefore, give the later (rightmost) hashes precedence.
    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
    my $meta = {};
    foreach my $reader (@{$self->{_readers}})
    {
        if ($reader->allow($filename))
        {
            print STDERR "Reader ", $reader->name(), " can read $filename\n" if $self->{verbose} > 1;
            my $info = $reader->read_meta($filename);
            my $newmeta = $merge->merge($meta, $info);
            $meta = $newmeta;
            print STDERR "META: ", Dump($meta), "\n" if $self->{verbose} > 1;
        }
    }

    return $meta;
} # read_meta

=head2 add_field_to_file

Add the contents of the given field to the file, taking into account multi-value fields.

    $sticker->add_field_to_file(
        filename=>$filename,
        field=>$field,
        value=>$value);

=cut
sub add_field_to_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $field = $args{field};
    my $value = $args{value};

    if (!-w $filename)
    {
        return undef;
    }
    my $old_meta = $self->read_meta($filename);

    foreach my $writer (@{$self->{_writers}})
    {
        if ($writer->allow($filename))
        {
            print STDERR "Writer ", $writer->name(), "can write $filename\n" if $self->{verbose} > 1;
            $writer->add_field_to_file(
                filename=>$filename,
                field=>$field,
                value=>$value,
                old_meta=>$old_meta);
        }
    }
}

=head2 delete_field_from_file

Completely remove the given field.
For multi-value fields, it removes ALL the values.

    $sticker->delete_field_from_file(filename=>$filename,field=>$field);

=cut

sub delete_field_from_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $field = $args{field};

    foreach my $writer (@{$self->{_writers}})
    {
        if ($writer->allow($filename))
        {
            print STDERR "Writer ", $writer->name(), " can write $filename\n" if $self->{verbose} > 1;
            $writer->delete_field_from_file(
                filename=>$filename,
                field=>$field);
        }
    }
} # delete_field_from_file

=head2 replace_all_meta

Overwrite the existing meta-data with that given.

    $sticker->replace_all_meta(filename=>$filename,meta=>\%meta);

=cut

sub replace_all_meta {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $meta = $args{meta};

    my $okay = 0;
    foreach my $writer (@{$self->{_writers}})
    {
        if ($writer->allow($filename))
        {
            print STDERR "Writer ", $writer->name(), " can write $filename\n" if $self->{verbose} > 1;
            $okay = 1;
            $writer->replace_all_meta(
                filename=>$filename,
                meta=>$meta);
        }
    }
    return $okay;
} # replace_all_meta

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of Text::ParseStory
__END__
