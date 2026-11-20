import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty({ message: 'Please enter your username.' })
  @MaxLength(50)
  username: string;

  @IsString()
  @IsNotEmpty({ message: 'Please enter your password.' })
  @MaxLength(200)
  password: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  refreshToken: string;
}
