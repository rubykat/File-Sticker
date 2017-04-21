package File::Sticker::Writer::Yaml;

=head1 NAME

File::Sticker::Writer::Yaml - write and standardize meta-data from YAML file

=head1 SYNOPSIS

    use File::Sticker::Writer::Yaml;

    my $obj = File::Sticker::Writer::Yaml->new(%args);

    my %meta = $obj->write_meta(%args);

=head1 DESCRIPTION

This will write meta-data from YAML files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use YAML::Any qw(Dump LoadFile);

use parent qw(File::Sticker::Writer);

=head1 METHODS

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
File must be plain text and end with '.yml'

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} eq 'text/plain'
            and $file =~ /\.yml$/)
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this writer knows about.
This writer has no limitations.

    my $known_fields = $writer->known_fields();

=cut

sub known_fields {
    my $self = shift;

    if ($self->{wanted_fields})
    {
        return $self->{wanted_fields};
    }
    return {};
} # known_fields

=head2 write_meta

Write the meta-data to the given file.

    $writer->write_meta(filename=>$filename, meta=>\%meta);

=cut

sub write_meta {
    my $self = shift;
    my %args = @_;

    my $filename = $args{filename};

} # write_meta

=cut

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
