import { Transform, Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { UserRole } from '../user.schema.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const PASSWORD_MESSAGE = 'Password must be at least 8 characters.';

export class CreateUserDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter a name.' })
  @MaxLength(100)
  name: string;

  @Transform(trim)
  @IsString()
  @Matches(/^\S+$/, { message: 'Usernames cannot contain spaces.' })
  @MaxLength(50)
  username: string;

  @IsString()
  @MinLength(8, { message: PASSWORD_MESSAGE })
  @MaxLength(200)
  password: string;

  @IsEnum(UserRole, { message: 'Please select a role.' })
  role: UserRole;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(30)
  phone?: string;
}

export class UpdateUserDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter a name.' })
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(8, { message: PASSWORD_MESSAGE })
  @MaxLength(200)
  password?: string;

  @IsOptional()
  @IsEnum(UserRole, { message: 'Please select a role.' })
  role?: UserRole;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(30)
  phone?: string;
}

export class ListUsersDto {
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit: number = 100;
}
